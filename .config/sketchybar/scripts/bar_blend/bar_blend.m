// Paints each bar column in the color of the window top edge below it. Fills the gaps
// at rounded corners. Curves the color change where a corner is over another window.
// sketchybar starts this helper, so sketchybar needs Screen Recording permission.
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

#include "../sketchybar.h"

// Sample below the 1pt light rim at the top of each window.
#define SAMPLE_DEPTH 1
// Largest corner to measure, in points.
#define CORNER_MAX 64

// Top left corner of a window, in points. The top right corner is its mirror image.
@interface Corner : NSObject
@property CGFloat reach;   // the edge is not fully opaque this far in from the side
@property CGFloat radius;  // radius of the visible curve; the edge fades out past it
@property CGImageRef mask; // opaque over the gap outside the window
@end

@implementation Corner
- (void)dealloc {
    CGImageRelease(_mask);
}
@end

// The bar on one display.
@interface Display : NSObject <SCStreamOutput, SCStreamDelegate> {
@public
    CGDirectDisplayID display_id;
    CGRect bounds;  // global coordinates in points
    CGFloat scale;  // pixels per point
    size_t width;   // in pixels, one column per pixel
    CGColorSpaceRef space; // the display color space; draw in it so colors do not shift
    uint32_t* seen;   // last row from the stream, BGRA
    uint32_t* row;    // last screenshot of the row, BGRA
    bool capturing;   // a screenshot is in progress
    bool pending;     // the row changed during the screenshot
    uint32_t* colors; // bar columns, BGRA, 0 is transparent
    bool covered;     // a window fills the display (full screen, slideshow)
}
@property NSWindow* window;
@property CALayer* band; // the bar: a 1-pixel-high image, stretched
@property SCContentFilter* filter;
@property SCStreamConfiguration* config;
@property SCStream* stream;
@end

// macOS moves windows below the menu bar and notch. This window must cover the bar.
@interface BarWindow : NSWindow
@end

@implementation BarWindow
- (NSRect)constrainFrameRect:(NSRect)frame toScreen:(NSScreen*)screen {
    return frame;
}
@end

static char** g_argv;
static int g_bar_height;
static NSMutableArray<Display*>* g_displays;
static NSMutableDictionary<NSNumber*, Corner*>* g_corners; // by window number
static dispatch_source_t g_sketchybar;
static bool g_covered; // a window fills a display

// These windows stay just below the bar so its items show. The bar is above normal
// windows, so it covers their shadows. When a window fills a display, the bar goes
// below normal windows so that window covers it. sketchybar misses slideshows.
static NSWindowLevel window_level(void) {
    return g_covered ? kCGBackstopMenuLevel - 1 : kCGFloatingWindowLevel - 1;
}

static void update_level(void) {
    bool covered = false;
    for (Display* d in g_displays) covered |= d->covered;
    if (covered == g_covered) return;
    g_covered = covered;
    sketchybar(covered ? "--bar topmost=off" : "--bar topmost=window");
    for (Display* d in g_displays) d.window.level = window_level();
}

static void restart(void) {
    // execv keeps the blocked signals of this thread, and capture callbacks block all of
    // them. Without this, the new process ignores SIGTERM from killall.
    sigset_t none;
    sigemptyset(&none);
    pthread_sigmask(SIG_SETMASK, &none, NULL);
    execv(g_argv[0], g_argv);
}

static void fail(NSError* error) {
    fprintf(stderr, "bar_blend: %s\n", error.localizedDescription.UTF8String);
    exit(1);
}

static void compute(Display* d);

// macOS does not give the corner radius, so read it from the alpha of a capture of the
// window. Until then, the corners are square.
static void measure_corner(NSNumber* number, Display* d, int attempt) {
    g_corners[number] = [Corner new];
    // A new window can be missing from the capture list.
    void (^retry)(void) = ^{
        if (attempt < 3)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (attempt + 1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                measure_corner(number, d, attempt + 1);
            });
    };
    CGFloat scale = d->scale;
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:YES
                                                 completionHandler:^(SCShareableContent* content, NSError* error) {
        SCWindow* window = nil;
        for (SCWindow* w in content.windows)
            if (w.windowID == number.unsignedIntValue) window = w;
        if (!window) {
            dispatch_async(dispatch_get_main_queue(), retry);
            return;
        }

        SCStreamConfiguration* config = [SCStreamConfiguration new];
        config.sourceRect = CGRectMake(0, 0, CORNER_MAX, CORNER_MAX);
        config.width = config.height = CORNER_MAX * scale;
        config.ignoreShadowsSingleWindow = YES;
        config.showsCursor = NO;
        SCContentFilter* filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:window];
        [SCScreenshotManager captureImageWithFilter:filter configuration:config
                                  completionHandler:^(CGImageRef image, NSError* error) {
            if (!image) {
                dispatch_async(dispatch_get_main_queue(), retry);
                return;
            }
            size_t size = CGImageGetWidth(image);
            CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, size, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
            CGContextDrawImage(context, CGRectMake(0, 0, size, size), image);
            const uint8_t* alpha = CGBitmapContextGetData(context);

            // The corner ends where the top row is as opaque as the straight edge.
            uint8_t edge = alpha[size - 1];
            size_t reach = 0;
            while (alpha[reach] < edge) reach++;
            // A circle crosses the diagonal at 29% of its radius.
            size_t diagonal = 0;
            while (diagonal < reach && alpha[diagonal * size + diagonal] < edge / 2) diagonal++;

            Corner* corner = [Corner new];
            corner.reach = reach / scale;
            corner.radius = MIN(diagonal / (1 - M_SQRT1_2), reach) / scale;
            // The fill is above the window. It covers only the transparent part, so the
            // window outline and its soft edge stay.
            if (reach > 0) {
                CGContextRef mask = CGBitmapContextCreate(NULL, reach, reach, 8, reach, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
                uint8_t* gap = CGBitmapContextGetData(mask);
                for (size_t y = 0; y < reach; y++)
                    for (size_t x = 0; x < reach; x++)
                        gap[y * reach + x] = 255 - MIN(alpha[y * size + x], edge) * 255 / edge;
                corner.mask = CGBitmapContextCreateImage(mask);
                CGContextRelease(mask);
            }
            CGContextRelease(context);

            dispatch_async(dispatch_get_main_queue(), ^{
                g_corners[number] = corner;
                for (Display* display in g_displays) compute(display);
            });
        }];
    }];
}

static size_t column(Display* d, double x) {
    return fmin(fmax((x - CGRectGetMinX(d->bounds)) * d->scale, 0), d->width);
}

// Sets the bar colors from the last screenshot and draws the bar.
static void compute(Display* d) {
    double bar_bottom = CGRectGetMinY(d->bounds) + g_bar_height;
    double sample_y = bar_bottom + SAMPLE_DEPTH;

    // Menus, popovers and the screenshot selection tint change the sampled pixels.
    // Columns below them keep their last color.
    bool overlaid[d->width];
    memset(overlaid, 0, sizeof(overlaid));
    NSArray* list = CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    NSMutableArray<NSNumber*>* numbers = [NSMutableArray new];
    CGRect bounds[list.count];
    int count = 0;
    d->covered = false;
    for (NSDictionary* window in list) {
        int layer = [window[(id)kCGWindowLayer] intValue];
        CGRect rect;
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds], &rect);
        if (layer > 0 && [window[(id)kCGWindowOwnerPID] intValue] != getpid()
            && CGRectGetMinY(rect) <= sample_y && CGRectGetMaxY(rect) > sample_y)
            for (size_t x = column(d, CGRectGetMinX(rect)); x < column(d, CGRectGetMaxX(rect)); x++) overlaid[x] = true;
        if (layer != 0) continue;
        d->covered |= CGRectContainsRect(rect, d->bounds);
        bounds[count++] = rect;
        [numbers addObject:window[(id)kCGWindowNumber]];
    }
    update_level();

    // Each column goes to the frontmost window that crosses the bar bottom. The column
    // gets a color only if the window top is at the bar bottom. Rounded corners do not
    // touch the bar, so a window behind that touches the bar gets those columns. If
    // there is none, the corner.s window keeps them.
    int owner[d->width];  // window in each column, -1 for none
    bool clean[d->width]; // the sampled pixel is from the owner
    bool claimed[d->width];
    Corner* corners[count];
    memset(owner, -1, sizeof(owner));
    memset(clean, 0, sizeof(clean));
    memset(claimed, 0, sizeof(claimed));
    for (int i = 0; i < count; i++) {
        corners[i] = nil;
        if (CGRectGetMinY(bounds[i]) > bar_bottom || CGRectGetMaxY(bounds[i]) <= bar_bottom) continue;

        bool touching = CGRectGetMinY(bounds[i]) == bar_bottom;
        if (touching) {
            if (!g_corners[numbers[i]]) measure_corner(numbers[i], d, 0);
            corners[i] = g_corners[numbers[i]];
        }
        // The window gets the bar from the end of its visible curve. The sampled row can
        // cross the outline anywhere in the corner, so only pixels past the reach are clean.
        size_t left = column(d, CGRectGetMinX(bounds[i])), right = column(d, CGRectGetMaxX(bounds[i]));
        size_t round_left = column(d, CGRectGetMinX(bounds[i]) + corners[i].radius);
        size_t round_right = column(d, CGRectGetMaxX(bounds[i]) - corners[i].radius);
        size_t edge_left = column(d, CGRectGetMinX(bounds[i]) + corners[i].reach);
        size_t edge_right = column(d, CGRectGetMaxX(bounds[i]) - corners[i].reach);
        for (size_t x = left; x < right; x++) {
            if (claimed[x]) continue;
            if (x >= round_left && x < round_right) {
                claimed[x] = true;
                clean[x] = touching && owner[x] < 0 && x >= edge_left && x < edge_right;
                owner[x] = touching ? i : -1;
            } else if (touching && owner[x] < 0) {
                owner[x] = i;
            }
        }
    }

    // Clean columns use their own pixel. The other columns are below a corner. They copy
    // the next pixel of their owner, from the left or else from the right.
    uint32_t* colors = d->colors;
    for (size_t x = 0; x < d->width; x++) colors[x] = !clean[x] ? 0 : overlaid[x] ? colors[x] : d->row[x];
    for (size_t x = 1; x < d->width; x++)
        if (!clean[x] && owner[x] >= 0 && owner[x] == owner[x - 1]) colors[x] = colors[x - 1];
    for (size_t x = d->width - 1; x-- > 0;)
        if (!colors[x] && owner[x] >= 0 && owner[x] == owner[x + 1]) colors[x] = colors[x + 1];

    // If a corner is over another window that touches the bar, the bar changes color
    // along a reversed curve of the corner radius. Then the window edge continues up
    // into the bar. If no other window overlaps a corner, its gap shows the bar columns.
    NSMutableArray<CALayer*>* layers = [NSMutableArray arrayWithObject:d.band];
    NSMutableArray<CALayer*>* fills = [NSMutableArray new];
    CGFloat origin = CGRectGetMinX(d->bounds), span = CGRectGetWidth(d->bounds);
    for (int i = 0; i < count; i++) {
        Corner* corner = corners[i];
        if (!corner.mask) continue;
        CGFloat radius = corner.radius, reach = corner.reach;
        for (int side = 0; side < 2; side++) {
            // The curve is in the columns after the corner. The window behind has the
            // corner columns.
            CGFloat x = side ? CGRectGetMaxX(bounds[i]) - 2 * radius : CGRectGetMinX(bounds[i]) + radius;
            size_t from = column(d, x), to = column(d, x + radius);
            size_t behind = side ? to : from - 1, front = side ? from - 1 : to;
            if (from > 0 && from < to && to < d->width && owner[behind] >= 0 && owner[behind] != i && owner[front] == i) {
                CAShapeLayer* curve = [CAShapeLayer layer];
                curve.frame = CGRectMake(x - origin, CORNER_MAX, radius, radius);
                curve.masksToBounds = YES;
                CGMutablePathRef path = CGPathCreateMutable();
                CGPathAddRect(path, NULL, curve.bounds);
                CGPathAddEllipseInRect(path, NULL, CGRectMake(side ? 0 : -radius, 0, 2 * radius, 2 * radius));
                curve.path = path;
                CGPathRelease(path);
                curve.fillRule = kCAFillRuleEvenOdd;
                uint32_t c = colors[front];
                CGFloat components[] = {(c >> 16 & 0xff) / 255.0, (c >> 8 & 0xff) / 255.0, (c & 0xff) / 255.0, 1};
                CGColorRef color = CGColorCreate(d->space, components);
                curve.fillColor = color;
                CGColorRelease(color);
                [layers addObject:curve];
                for (size_t x = from; x < to; x++) colors[x] = colors[behind];
                continue;
            }

            x = side ? CGRectGetMaxX(bounds[i]) - reach : CGRectGetMinX(bounds[i]);
            bool overlapped = false;
            for (int j = 0; j < count; j++)
                overlapped |= j != i && CGRectIntersectsRect(bounds[j], CGRectMake(x, bar_bottom, reach, reach));
            size_t next = side ? column(d, x) - 1 : column(d, x + reach);
            if (overlapped || next >= d->width || owner[next] != i || !clean[next]) continue;
            CALayer* fill = [CALayer layer];
            fill.frame = CGRectMake(x - origin, CORNER_MAX - reach, reach, reach);
            fill.contentsRect = CGRectMake((x - origin) / span, 0, reach / span, 1);
            fill.magnificationFilter = kCAFilterNearest;
            fill.mask = [CALayer layer];
            fill.mask.frame = fill.bounds;
            fill.mask.contents = (__bridge id)corner.mask;
            if (side) fill.mask.affineTransform = CGAffineTransformMakeScale(-1, 1);
            [fills addObject:fill];
        }
    }

    CGContextRef bitmap = CGBitmapContextCreate(colors, d->width, 1, 8, d->width * 4, d->space,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    d.band.contents = (__bridge id)image;
    for (CALayer* fill in fills) fill.contents = (__bridge id)image;
    d.window.contentView.layer.sublayers = [layers arrayByAddingObjectsFromArray:fills];
    [CATransaction commit];
    CGImageRelease(image);
}

// Stream colors are slightly shifted. A stream change only starts a screenshot of the
// same rows, which has exact colors.
static void screenshot(Display* d) {
    if (d->capturing) {
        d->pending = true;
        return;
    }
    d->capturing = true;
    [SCScreenshotManager captureSampleBufferWithFilter:d.filter configuration:d.config
                                     completionHandler:^(CMSampleBufferRef sample, NSError* error) {
        NSData* middle = nil;
        CVPixelBufferRef buffer = sample ? CMSampleBufferGetImageBuffer(sample) : NULL;
        if (buffer && CVPixelBufferGetWidth(buffer) >= d->width && CVPixelBufferGetHeight(buffer) >= 3) {
            CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t* base = CVPixelBufferGetBaseAddress(buffer);
            middle = [NSData dataWithBytes:base + CVPixelBufferGetBytesPerRow(buffer) length:d->width * 4];
            CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            d->capturing = false;
            if (middle && memcmp(middle.bytes, d->row, d->width * 4) != 0) {
                memcpy(d->row, middle.bytes, d->width * 4);
                compute(d);
            }
            if (d->pending) {
                d->pending = false;
                screenshot(d);
            }
        });
    }];
}

@implementation Display
- (void)stream:(SCStream*)stream didOutputSampleBuffer:(CMSampleBufferRef)sample ofType:(SCStreamOutputType)type {
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sample);
    if (!buffer || CVPixelBufferGetWidth(buffer) < width || CVPixelBufferGetHeight(buffer) < 3) return;
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    const uint8_t* base = CVPixelBufferGetBaseAddress(buffer);
    const uint32_t* middle = (const uint32_t*)(base + CVPixelBufferGetBytesPerRow(buffer));
    if (memcmp(middle, seen, width * 4) != 0) {
        memcpy(seen, middle, width * 4);
        screenshot(self);
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
}

- (void)stream:(SCStream*)stream didStopWithError:(NSError*)error {
    fprintf(stderr, "bar_blend: capture stopped: %s\n", error.localizedDescription.UTF8String);
    sleep(1);
    restart();
}
@end

static void display_changed(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void* info) {
    if (!(flags & kCGDisplayBeginConfigurationFlag)) restart();
}

static Display* add_display(SCDisplay* screen) {
    Display* d = [Display new];
    d->display_id = screen.displayID;
    d->bounds = CGDisplayBounds(d->display_id);
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(d->display_id);
    d->scale = (CGFloat)CGDisplayModeGetPixelWidth(mode) / CGDisplayModeGetWidth(mode);
    CGDisplayModeRelease(mode);
    d->width = CGRectGetWidth(d->bounds) * d->scale;
    d->space = CGDisplayCopyColorSpace(d->display_id);
    d->seen = calloc(d->width, 4);
    d->row = calloc(d->width, 4);
    d->colors = calloc(d->width, 4);

    NSRect frame = NSZeroRect;
    for (NSScreen* s in NSScreen.screens)
        if ([s.deviceDescription[@"NSScreenNumber"] unsignedIntValue] == d->display_id) frame = s.frame;
    d.window = [[BarWindow alloc]
        initWithContentRect:NSMakeRect(NSMinX(frame), NSMaxY(frame) - g_bar_height - CORNER_MAX,
                                       NSWidth(frame), g_bar_height + CORNER_MAX)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    d.window.opaque = NO;
    d.window.backgroundColor = NSColor.clearColor;
    d.window.hasShadow = NO;
    d.window.ignoresMouseEvents = YES;
    d.window.level = window_level();
    d.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
        | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;
    // A layer-hosting view, so AppKit does not change its layers.
    NSView* view = [NSView new];
    view.layer = [CALayer layer];
    view.wantsLayer = YES;
    d.band = [CALayer layer];
    d.band.frame = CGRectMake(0, CORNER_MAX, CGRectGetWidth(d->bounds), g_bar_height);
    d.band.magnificationFilter = kCAFilterNearest;
    d.window.contentView = view;
    [d.window orderFrontRegardless];

    // Capture three rows and read the middle one. The outer rows can mix with the
    // transparent pixels outside the capture.
    d.config = [SCStreamConfiguration new];
    d.config.sourceRect = CGRectMake(0, g_bar_height + SAMPLE_DEPTH - 1 / d->scale, CGRectGetWidth(d->bounds), 3 / d->scale);
    d.config.width = d->width;
    d.config.height = 3;
    d.config.pixelFormat = kCVPixelFormatType_32BGRA;
    d.config.showsCursor = NO;
    d.config.minimumFrameInterval = CMTimeMake(1, 20);

    d.filter = [[SCContentFilter alloc] initWithDisplay:screen excludingWindows:@[]];
    d.stream = [[SCStream alloc] initWithFilter:d.filter configuration:d.config delegate:d];
    NSError* error = nil;
    if (![d.stream addStreamOutput:d type:SCStreamOutputTypeScreen sampleHandlerQueue:dispatch_get_main_queue() error:&error])
        fail(error);
    [d.stream startCaptureWithCompletionHandler:^(NSError* error) {
        if (error) fail(error);
    }];
    return d;
}

int main(int argc, char** argv) {
    g_argv = argv;
    const char* bar_height = getenv("BAR_HEIGHT");
    g_bar_height = bar_height ? atoi(bar_height) : 0;
    if (g_bar_height <= 0) {
        fprintf(stderr, "bar_blend: BAR_HEIGHT is not set\n");
        return 1;
    }

    // Exit when sketchybar exits.
    mach_port_t port = mach_get_bs_port();
    if (!port) return 0;
    g_sketchybar = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_SEND, port, DISPATCH_MACH_SEND_DEAD,
                                          dispatch_get_main_queue());
    dispatch_source_set_event_handler(g_sketchybar, ^{
        exit(0);
    });
    dispatch_resume(g_sketchybar);

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    g_displays = [NSMutableArray new];
    g_corners = [NSMutableDictionary new];

    // Restart when the displays change.
    CGDisplayRegisterReconfigurationCallback(display_changed, NULL);

    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent* content, NSError* error) {
        if (error) fail(error);
        dispatch_async(dispatch_get_main_queue(), ^{
            for (SCDisplay* screen in content.displays) [g_displays addObject:add_display(screen)];
        });
    }];

    [NSApp run];
    return 0;
}
