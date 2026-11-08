// Paints the bar in the colors of the windows whose top is at the bar bottom, and fills
// the gaps at their rounded top corners. sketchybar starts this helper, so sketchybar
// needs Screen Recording permission.
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

#include "../sketchybar.h"

// Sample this far below the bar, in points. This skips the light rim and the borders that
// some apps draw on their top edge, for example the 2pt border of Rex.
#define SAMPLE_DEPTH 3
// Depth below the bar that corner gaps can reach, in points.
#define CORNER_DEPTH 32

// The bar on one display.
@interface Display : NSObject {
@public
    CGDirectDisplayID display_id;
    CGRect bounds;  // global coordinates in points
    CGFloat scale;  // pixels per point
    size_t width;   // in pixels, one column per pixel
    size_t rows;    // CORNER_DEPTH in pixels
    CGColorSpaceRef space; // the display color space; draw in it so colors do not shift
    uint32_t* row;    // screen colors SAMPLE_DEPTH below the bar, BGRA
    uint32_t* colors; // bar columns, BGRA, 0 is transparent
    bool capturing;   // a screenshot is in progress
    bool changing;    // the last screenshot found a change
    bool moved;       // the windows just below the bar changed
    bool covered;     // a window fills the display (full screen, slideshow)
    bool dark;        // the bar is dark behind the left items
}
@property NSWindow* window;
@property CALayer* band;     // the bar: a 1-pixel-high image, stretched
@property CALayer* fill;     // the same image below the bar, masked to the corner gaps
@property NSArray* numbers;  // the windows just below the bar at the last check
@property NSArray* touching; // those whose top is at the bar bottom, front first
@property NSArray* windows;  // their place and title
@property SCContentFilter* screen; // made again when the window numbers change
@property NSArray* filters;  // each window at the bar bottom alone
@property NSArray* filtered; // their window numbers
@property NSArray<NSData*>* shapes; // the alpha below the bar of each, by row
@property NSArray* shaped;   // their window numbers
@property SCStreamConfiguration* row_config;
@property SCStreamConfiguration* shape_config;
@end

@implementation Display
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
static NSArray* g_list; // the on-screen windows at the last check, front to back
static dispatch_source_t g_sketchybar;
static dispatch_source_t g_timer;
static bool g_covered; // a window fills a display

// These windows stay one level below the bar, so the bar items show. The bar is above
// normal windows, so it covers their shadows. When a window fills a display, the bar
// goes below normal windows, and that window covers it. sketchybar misses slideshows.
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

static size_t column(Display* d, double x) {
    return fmin(fmax((x - CGRectGetMinX(d->bounds)) * d->scale, 0), d->width);
}

// Sets the bar colors from the last screenshots and draws the bar.
static void compute(Display* d) {
    size_t width = d->width, rows = d->rows;
    bool items[width]; // below the bar items on the left
    memset(items, 0, sizeof(items));
    NSMutableDictionary<NSNumber*, NSValue*>* frames = [NSMutableDictionary new];
    d->covered = false;
    for (NSDictionary* window in g_list) {
        CGRect rect;
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds], &rect);
        if ([window[(id)kCGWindowOwnerName] isEqualToString:@"sketchybar"] && CGRectGetMinY(rect) == CGRectGetMinY(d->bounds)
            && CGRectGetHeight(rect) == g_bar_height && CGRectGetMaxX(rect) <= CGRectGetMidX(d->bounds))
            for (size_t x = column(d, CGRectGetMinX(rect)); x < column(d, CGRectGetMaxX(rect)); x++) items[x] = true;
        if ([window[(id)kCGWindowLayer] intValue] != 0) continue;
        d->covered |= CGRectContainsRect(rect, d->bounds);
        frames[window[(id)kCGWindowNumber]] = [NSValue valueWithRect:rect];
    }
    update_level();

    // For each column, the frontmost window at the bar bottom that reaches the bar, and the
    // first row where any of them is opaque: 0 where a window reaches the bar, more in a
    // corner gap, and rows where there is no window.
    NSArray<NSData*>* shapes = d.shapes;
    int count = (int)shapes.count;
    const uint8_t* alpha[count + 1];
    for (int i = 0; i < count; i++) alpha[i] = shapes[i].bytes;
    int owner[width];
    size_t top[width];
    for (size_t x = 0; x < width; x++) {
        owner[x] = -1;
        top[x] = rows;
        for (int i = 0; i < count; i++) {
            size_t y = 0;
            while (y < top[x] && alpha[i][y * width + x] < 128) y++;
            top[x] = y;
            if (!y && owner[x] < 0) owner[x] = i;
        }
    }

    // A column where a window reaches the bar takes the screen color below it. A column
    // in a corner copies the next column toward the inside of its window, where the
    // corner is lower.
    uint32_t* colors = d->colors;
    for (size_t x = 0; x < width; x++) colors[x] = top[x] ? 0 : d->row[x];
    for (size_t x = 1; x < width; x++)
        if (!colors[x] && top[x] < rows && top[x - 1] <= top[x]) colors[x] = colors[x - 1];
    for (size_t x = width - 1; x-- > 0;)
        if (!colors[x] && top[x] < rows && top[x + 1] <= top[x]) colors[x] = colors[x + 1];

    // If a corner is over a window behind that reaches the bar, the bar keeps the color of
    // that window above the corner, and changes color along a reversed curve of the corner
    // radius. Then the window edge continues up into the bar.
    NSMutableArray<CALayer*>* layers = [NSMutableArray arrayWithObject:d.band];
    CGFloat origin = CGRectGetMinX(d->bounds);
    NSArray* shaped = d.shaped;
    for (int i = 0; i < count; i++) {
        NSValue* value = frames[shaped[i]];
        if (!value) continue;
        CGRect frame = value.rectValue;
        for (int side = 0; side < 2; side++) {
            ssize_t edge = side ? (ssize_t)column(d, CGRectGetMaxX(frame)) - 1 : (ssize_t)column(d, CGRectGetMinX(frame));
            if (edge < 0 || edge >= (ssize_t)width || owner[edge] <= i) continue;
            // A circle crosses the diagonal from its corner at 29% of its radius.
            ssize_t step = 0, room = side ? edge : (ssize_t)width - 1 - edge;
            while (step < (ssize_t)rows && step < room && alpha[i][step * width + edge + (side ? -step : step)] < 128) step++;
            // Whole pixels, so the curve ends on the columns where the bar changes color.
            CGFloat radius = round(step / (1 - M_SQRT1_2)) / d->scale;
            CGFloat x = side ? CGRectGetMaxX(frame) - 2 * radius : CGRectGetMinX(frame) + radius;
            size_t from = column(d, x), to = column(d, x + radius);
            size_t front = side ? from - 1 : to;
            if (!from || from >= to || to >= width || owner[front] != i) continue;
            for (size_t c = side ? from : edge; c < (side ? edge + 1 : to); c++) colors[c] = colors[edge];
            // The window color fills the corner of the square below the arc. The arc is its
            // only edge in the bar, so no outline of the square shows.
            CAShapeLayer* curve = [CAShapeLayer layer];
            curve.frame = CGRectMake(x - origin, CORNER_DEPTH, radius, radius);
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathMoveToPoint(path, NULL, side ? radius : 0, 0);
            CGPathAddArc(path, NULL, side ? radius : 0, radius, radius, -M_PI_2, side ? -M_PI : 0, side);
            CGPathAddLineToPoint(path, NULL, side ? 0 : radius, 0);
            CGPathCloseSubpath(path);
            curve.path = path;
            CGPathRelease(path);
            uint32_t c = colors[front];
            CGFloat components[] = {(c >> 16 & 0xff) / 255.0, (c >> 8 & 0xff) / 255.0, (c & 0xff) / 255.0, 1};
            CGColorRef color = CGColorCreate(d->space, components);
            curve.fillColor = color;
            CGColorRelease(color);
            [layers addObject:curve];
        }
    }
    [layers addObject:d.fill];

    // The fill covers the transparent part of each corner gap, so the window outline and
    // its soft edge stay.
    CGContextRef mask = CGBitmapContextCreate(NULL, width, rows, 8, width, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    uint8_t* gaps = CGBitmapContextGetData(mask);
    for (size_t y = 0; y < rows; y++)
        for (size_t x = 0; x < width; x++) {
            uint8_t opaque = 0;
            for (int i = 0; i < count; i++) opaque = MAX(opaque, alpha[i][y * width + x]);
            gaps[y * width + x] = colors[x] && y < top[x] ? 255 - opaque : 0;
        }
    CGImageRef gaps_image = CGBitmapContextCreateImage(mask);
    CGContextRelease(mask);

    CGContextRef bitmap = CGBitmapContextCreate(colors, width, 1, 8, width * 4, d->space,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextRelease(bitmap);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    d.band.contents = (__bridge id)image;
    d.fill.contents = (__bridge id)image;
    d.fill.mask.contents = (__bridge id)gaps_image;
    d.window.contentView.layer.sublayers = layers;
    [CATransaction commit];
    CGImageRelease(image);
    CGImageRelease(gaps_image);

    // The bar is dark if its mean luma behind the left items is below mid-gray. A
    // transparent column counts as light, so items over the wallpaper stay dark.
    double luma = 0;
    size_t n = 0;
    for (size_t x = 0; x < width; x++) {
        if (!items[x]) continue;
        uint32_t c = colors[x] ? colors[x] : 0xffffffff;
        luma += 0.2126 * (c >> 16 & 0xff) + 0.7152 * (c >> 8 & 0xff) + 0.0722 * (c & 0xff);
        n++;
    }
    if (n && (luma < 128 * n) != d->dark) {
        d->dark = !d->dark;
        update_dark();
    }
}

// A capture stream counts as screen sharing, which hides notifications. So take
// screenshots when the windows just below the bar change, again until they stop
// changing, and every 2 seconds for other color changes in windows. One screenshot reads
// the screen colors without this helper and the windows above normal windows: menus,
// banners and the screenshot selection tint. The others read the alpha of each window at
// the bar bottom alone, which gives its corners. Translucent windows need both: alone,
// they do not show the blur behind them.
static void capture(Display* d) {
    size_t width = d->width, rows = d->rows;
    NSArray* filters = d.filters, * numbers = d.filtered;
    __block NSData* row = nil;
    NSMutableArray* shapes = [NSMutableArray new];
    for (NSUInteger i = 0; i < filters.count; i++) [shapes addObject:NSNull.null];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [SCScreenshotManager captureSampleBufferWithFilter:d.screen configuration:d.row_config
                                     completionHandler:^(CMSampleBufferRef sample, NSError* error) {
        CVPixelBufferRef buffer = sample ? CMSampleBufferGetImageBuffer(sample) : NULL;
        if (buffer && CVPixelBufferGetWidth(buffer) >= width && CVPixelBufferGetHeight(buffer) >= 3) {
            CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t* base = CVPixelBufferGetBaseAddress(buffer);
            row = [NSData dataWithBytes:base + CVPixelBufferGetBytesPerRow(buffer) length:width * 4];
            CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        }
        dispatch_group_leave(group);
    }];
    [filters enumerateObjectsUsingBlock:^(SCContentFilter* filter, NSUInteger i, BOOL* stop) {
        dispatch_group_enter(group);
        [SCScreenshotManager captureSampleBufferWithFilter:filter configuration:d.shape_config
                                         completionHandler:^(CMSampleBufferRef sample, NSError* error) {
            CVPixelBufferRef buffer = sample ? CMSampleBufferGetImageBuffer(sample) : NULL;
            if (buffer && CVPixelBufferGetWidth(buffer) >= width && CVPixelBufferGetHeight(buffer) >= rows) {
                CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
                const uint8_t* base = CVPixelBufferGetBaseAddress(buffer);
                size_t stride = CVPixelBufferGetBytesPerRow(buffer);
                NSMutableData* alpha = [NSMutableData dataWithLength:width * rows];
                uint8_t* a = alpha.mutableBytes;
                for (size_t y = 0; y < rows; y++)
                    for (size_t x = 0; x < width; x++) a[y * width + x] = base[y * stride + x * 4 + 3];
                CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
                @synchronized (shapes) {
                    shapes[i] = alpha;
                }
            }
            dispatch_group_leave(group);
        }];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        d->capturing = false;
        bool changed = false;
        if (row && memcmp(row.bytes, d->row, width * 4)) {
            memcpy(d->row, row.bytes, width * 4);
            changed = true;
        }
        // Keep the last shapes if a capture failed.
        if (![shapes containsObject:NSNull.null] && (![shapes isEqualToArray:d.shapes] || ![numbers isEqualToArray:d.shaped])) {
            d.shapes = shapes;
            d.shaped = numbers;
            changed = true;
        }
        d->changing = changed || d->moved;
        d->moved = false;
        if (d->changing) compute(d);
    });
}

static void screenshot(Display* d) {
    if (d->capturing) return;
    d->capturing = true;
    if (d.screen) {
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
        NSMutableDictionary* windows = [NSMutableDictionary new];
        for (SCWindow* w in content.windows) {
            if (w.windowLayer > 0 || w.owningApplication.processID == getpid()) [skip addObject:w];
            windows[@(w.windowID)] = w;
        }
        NSMutableArray* filters = [NSMutableArray new];
        NSMutableArray* filtered = [NSMutableArray new];
        for (NSNumber* number in d.touching) {
            if (!windows[number]) continue;
            [filters addObject:[[SCContentFilter alloc] initWithDisplay:display includingWindows:@[windows[number]]]];
            [filtered addObject:number];
        }
        d.screen = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:skip];
        d.filters = filters;
        d.filtered = filtered;
        capture(d);
        // A new window can be missing from the list, so list again next time.
        if (filtered.count < d.touching.count) d.screen = nil;
    }];
}

// Checks the windows just below the bar on each display: their place, order and
// title. A browser title changes with the tab, and so does its color. Windows inside
// the bar, like the recording indicator that each screenshot shows, do not count.
// compute uses the same window list.
static void tick(void) {
    static int ticks;
    bool periodic = ++ticks % 20 == 0;
    g_list = CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    pid_t own_pid = getpid();
    for (Display* d in g_displays) {
        double bar_bottom = CGRectGetMinY(d->bounds) + g_bar_height;
        CGRect below = CGRectMake(CGRectGetMinX(d->bounds), bar_bottom, CGRectGetWidth(d->bounds), CORNER_DEPTH);
        NSMutableArray* numbers = [NSMutableArray new];
        NSMutableArray* touching = [NSMutableArray new];
        NSMutableArray* windows = [NSMutableArray new];
        for (NSDictionary* w in g_list) {
            CGRect rect;
            CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds], &rect);
            if (!CGRectIntersectsRect(rect, below) || [w[(id)kCGWindowOwnerPID] intValue] == own_pid) continue;
            [numbers addObject:w[(id)kCGWindowNumber]];
            if ([w[(id)kCGWindowLayer] intValue] == 0 && CGRectGetMinY(rect) == bar_bottom)
                [touching addObject:w[(id)kCGWindowNumber]];
            [windows addObject:@[w[(id)kCGWindowBounds], w[(id)kCGWindowName] ?: @""]];
        }
        // The filters name windows, so only new, closed or moved windows change them.
        // Making them again lists all windows on the system.
        if (![numbers isEqualToArray:d.numbers] || ![touching isEqualToArray:d.touching]) {
            d.numbers = numbers;
            d.touching = touching;
            d.screen = nil;
            d->moved = true;
        }
        if (![windows isEqualToArray:d.windows]) {
            d.windows = windows;
            d->moved = true;
        }
        if (d->moved || periodic || d->changing) screenshot(d);
    }
}

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
    d->rows = CORNER_DEPTH * d->scale;
    d->space = CGDisplayCopyColorSpace(d->display_id);
    d->row = calloc(d->width, 4);
    d->colors = calloc(d->width, 4);

    NSRect frame = NSZeroRect;
    for (NSScreen* s in NSScreen.screens)
        if ([s.deviceDescription[@"NSScreenNumber"] unsignedIntValue] == d->display_id) frame = s.frame;
    d.window = [[BarWindow alloc]
        initWithContentRect:NSMakeRect(NSMinX(frame), NSMaxY(frame) - g_bar_height - CORNER_DEPTH,
                                       NSWidth(frame), g_bar_height + CORNER_DEPTH)
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
    d.band.frame = CGRectMake(0, CORNER_DEPTH, CGRectGetWidth(d->bounds), g_bar_height);
    d.band.magnificationFilter = kCAFilterNearest;
    d.fill = [CALayer layer];
    d.fill.frame = CGRectMake(0, 0, CGRectGetWidth(d->bounds), CORNER_DEPTH);
    d.fill.magnificationFilter = kCAFilterNearest;
    d.fill.mask = [CALayer layer];
    d.fill.mask.frame = d.fill.bounds;
    view.layer.sublayers = @[d.band, d.fill];
    d.window.contentView = view;
    [d.window orderFrontRegardless];

    // Capture three rows and read the middle one. The outer rows can mix with the
    // transparent pixels outside the capture.
    d.row_config = [SCStreamConfiguration new];
    d.row_config.sourceRect = CGRectMake(0, g_bar_height + SAMPLE_DEPTH - 1 / d->scale, CGRectGetWidth(d->bounds), 3 / d->scale);
    d.row_config.width = d->width;
    d.row_config.height = 3;
    d.row_config.pixelFormat = kCVPixelFormatType_32BGRA;
    d.row_config.showsCursor = NO;
    // Leave out shadows and the wallpaper, so the alpha is the window alone.
    d.shape_config = [SCStreamConfiguration new];
    d.shape_config.sourceRect = CGRectMake(0, g_bar_height, CGRectGetWidth(d->bounds), CORNER_DEPTH);
    d.shape_config.width = d->width;
    d.shape_config.height = d->rows;
    d.shape_config.pixelFormat = kCVPixelFormatType_32BGRA;
    d.shape_config.backgroundColor = CGColorGetConstantColor(kCGColorClear);
    d.shape_config.ignoreShadowsDisplay = YES;
    d.shape_config.showsCursor = NO;
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
