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
@interface Display : NSObject {
@public
    CGDirectDisplayID display_id;
    CGRect bounds;  // global coordinates in points
    CGFloat scale;  // pixels per point
    size_t width;   // in pixels, one column per pixel
    CGColorSpaceRef space; // the display color space; draw in it so colors do not shift
    uint32_t* row;    // last screenshot of the row, BGRA
    bool capturing;   // a screenshot is in progress
    bool changing;    // the last screenshot found a change
    bool moved;       // the windows just below the bar changed
    uint32_t* colors; // bar columns, BGRA, 0 is transparent
    bool covered;     // a window fills the display (full screen, slideshow)
    bool dark;        // the bar is dark behind the left items
}
@property NSWindow* window;
@property CALayer* band;    // the bar: a 1-pixel-high image, stretched
@property NSArray* windows; // the windows just below the bar at the last check
@property SCContentFilter* filter; // made again when those windows change
@property SCStreamConfiguration* config;
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
static dispatch_source_t g_timer;
static bool g_covered;     // a window fills a display

// These windows stay one level below the bar so its items show. The bar is above normal
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

// The workspace scripts draw the unboxed items in a light color on the displays in
// this file.
static void update_dark(void) {
    NSMutableString* ids = [NSMutableString new];
    for (Display* d in g_displays)
        if (d->dark) [ids appendFormat:@"%u ", d->display_id];
    [ids writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"sketchybar_dark_displays"]
          atomically:YES encoding:NSUTF8StringEncoding error:nil];
    sketchybar("--trigger bar_dark_changed");
}

static void restart(void) {
    // execv keeps the blocked signals of this thread. Callback threads block all of
    // them, and then the new process ignores SIGTERM from killall.
    sigset_t none;
    sigemptyset(&none);
    pthread_sigmask(SIG_SETMASK, &none, NULL);
    execv(g_argv[0], g_argv);
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
            // A capture during a change, like unlocking the screen, can miss the top
            // rows. The edge is never transparent, so measure again.
            if (!edge) {
                CGContextRelease(context);
                dispatch_async(dispatch_get_main_queue(), retry);
                return;
            }
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
    bool items[d->width]; // below the bar items on the left
    memset(items, 0, sizeof(items));
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
        if ([window[(id)kCGWindowOwnerName] isEqualToString:@"sketchybar"] && CGRectGetMinY(rect) == CGRectGetMinY(d->bounds)
            && CGRectGetHeight(rect) == g_bar_height && CGRectGetMaxX(rect) <= CGRectGetMidX(d->bounds))
            for (size_t x = column(d, CGRectGetMinX(rect)); x < column(d, CGRectGetMaxX(rect)); x++) items[x] = true;
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
    for (size_t x = 0; x < d->width; x++) colors[x] = clean[x] ? d->row[x] : 0;
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

    // The bar is dark if its mean luma behind the left items is below mid-gray. Below a
    // transparent column, the row shows what the bar shows.
    double luma = 0;
    size_t n = 0;
    for (size_t x = 0; x < d->width; x++) {
        if (!items[x]) continue;
        uint32_t c = colors[x] ? colors[x] : d->row[x];
        luma += 0.2126 * (c >> 16 & 0xff) + 0.7152 * (c >> 8 & 0xff) + 0.0722 * (c & 0xff);
        n++;
    }
    if (n && (luma < 128 * n) != d->dark) {
        d->dark = !d->dark;
        update_dark();
    }
}

// A capture stream counts as screen sharing, which hides notifications. So take a
// screenshot when the windows just below the bar change, again until the row stops
// changing, and every 2 seconds for other color changes in windows. The screenshot
// leaves out the windows of this helper and the windows above normal windows: menus,
// banners and the screenshot selection tint.
static void capture(Display* d) {
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
            bool changed = middle && memcmp(middle.bytes, d->row, d->width * 4) != 0;
            if (changed) memcpy(d->row, middle.bytes, d->width * 4);
            d->changing = changed || d->moved;
            d->moved = false;
            if (d->changing) compute(d);
        });
    }];
}

static void screenshot(Display* d) {
    if (d->capturing) return;
    d->capturing = true;
    if (d.filter) {
        capture(d);
        return;
    }
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:YES
                                                 completionHandler:^(SCShareableContent* content, NSError* error) {
        if (error) {
            fprintf(stderr, "bar_blend: %s\n", error.localizedDescription.UTF8String);
            exit(1);
        }
        SCDisplay* display = nil;
        for (SCDisplay* s in content.displays)
            if (s.displayID == d->display_id) display = s;
        NSMutableArray* skip = [NSMutableArray new];
        for (SCWindow* w in content.windows)
            if (w.windowLayer > 0 || w.owningApplication.processID == getpid()) [skip addObject:w];
        d.filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:skip];
        capture(d);
    }];
}

// Checks the windows just below the bar on each display: their place, order and
// title. A browser title changes with the tab, and so does its color. Windows inside
// the bar, like the recording indicator that each screenshot shows, do not count.
static void tick(void) {
    static int ticks;
    bool periodic = ++ticks % 20 == 0;
    NSArray* list = CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    for (Display* d in g_displays) {
        CGRect below = CGRectMake(CGRectGetMinX(d->bounds), CGRectGetMinY(d->bounds) + g_bar_height,
                                  CGRectGetWidth(d->bounds), CORNER_MAX);
        NSMutableArray* windows = [NSMutableArray new];
        for (NSDictionary* w in list) {
            CGRect rect;
            CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds], &rect);
            if (CGRectIntersectsRect(rect, below) && [w[(id)kCGWindowOwnerPID] intValue] != getpid())
                [windows addObject:@[w[(id)kCGWindowNumber], w[(id)kCGWindowBounds], w[(id)kCGWindowName] ?: @""]];
        }
        if (![windows isEqualToArray:d.windows]) {
            d.windows = windows;
            d.filter = nil;
            d->moved = true;
        }
        if (d->moved || periodic || d->changing) screenshot(d);
    }
}

@implementation Display
@end

static void display_changed(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void* info) {
    if (!(flags & kCGDisplayBeginConfigurationFlag)) restart();
}

static Display* add_display(CGDirectDisplayID display_id) {
    Display* d = [Display new];
    d->display_id = display_id;
    d->bounds = CGDisplayBounds(d->display_id);
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(d->display_id);
    d->scale = (CGFloat)CGDisplayModeGetPixelWidth(mode) / CGDisplayModeGetWidth(mode);
    CGDisplayModeRelease(mode);
    d->width = CGRectGetWidth(d->bounds) * d->scale;
    d->space = CGDisplayCopyColorSpace(d->display_id);
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

    uint32_t count;
    CGDirectDisplayID ids[16];
    CGGetActiveDisplayList(16, ids, &count);
    for (uint32_t i = 0; i < count; i++) [g_displays addObject:add_display(ids[i])];
    update_dark();

    g_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(g_timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 10, NSEC_PER_SEC / 100);
    dispatch_source_set_event_handler(g_timer, ^{
        tick();
    });
    dispatch_resume(g_timer);

    [NSApp run];
    return 0;
}
