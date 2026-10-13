// Pictures of web pages, by WebKit: an offscreen WKWebView per job loads
// the page, and its snapshot is written as a PNG. Everything is on the
// main thread, which must be running its run loop (SDL's event pump does).

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#define WS_JOBS 16
#define WS_MESSAGE 160

enum { WS_IDLE = 0, WS_WORKING = 1, WS_DONE = 2, WS_FAILED = 3 };

static const NSTimeInterval kLoadTimeout = 45.0;
static const int kPixelsPerPoint = 2;
static const int kMaxPixels = 16384;  // a texture's side, at most
static const NSTimeInterval kSettle = 0.6;  // after load, for late layout

@class WSJob;

static WSJob *jobs[WS_JOBS];
static int states[WS_JOBS];
static int heights[WS_JOBS];
static double phases[WS_JOBS];  // how far on, 0..1, once the page is loaded
static char messages[WS_JOBS][WS_MESSAGE];
static char titles[WS_JOBS][WS_MESSAGE];  // of the page, once Done

static void finish(int slot, int state, int height, NSString *message)
{
    states[slot] = state;
    heights[slot] = height;
    strlcpy(messages[slot], message.UTF8String ?: "", WS_MESSAGE);
    jobs[slot] = nil;
}

@interface WSJob : NSObject <WKNavigationDelegate>
@property int slot;
@property(strong) WKWebView *view;
@property(copy) NSString *path;
@property int width;
@property int maxHeight;
@property BOOL finished;
@end

@implementation WSJob

- (void)fail:(NSString *)why
{
    if (self.finished) return;
    self.finished = YES;
    finish(self.slot, WS_FAILED, 0, why);
}

- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)nav
{
    phases[self.slot] = 0.8;
    __weak WSJob *me = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSettle * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [me measure]; });
}

- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)nav withError:(NSError *)error
{
    [self fail:error.localizedDescription];
}

- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)nav withError:(NSError *)error
{
    [self fail:error.localizedDescription];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)view
{
    [self fail:@"The page's process stopped"];
}

- (void)measure
{
    if (self.finished) return;
    phases[self.slot] = 0.9;
    NSString *script =
        @"Math.max(document.documentElement.scrollHeight,"
         "document.body ? document.body.scrollHeight : 0)";
    __weak WSJob *me = self;
    [self.view evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        WSJob *job = me;
        if (!job || job.finished) return;
        int high = [result respondsToSelector:@selector(intValue)] ? [result intValue] : 0;
        if (high < 1) high = 1;
        if (high > job.maxHeight) high = job.maxHeight;
        [job shoot:high];
    }];
}

- (void)shoot:(int)high
{
    self.view.frame = NSMakeRect(0, 0, self.width, high);
    WKSnapshotConfiguration *config = [WKSnapshotConfiguration new];
    config.rect = NSMakeRect(0, 0, self.width, high);
    // Twice as many pixels as points, for small text to be read (by Vision)
    // and drawn well, unless the page is so long that that would be more
    // pixels than a GPU texture can have down it: then as many as can be.
    // The snapshot's width is in points, and the picture has the screen's
    // backing scale (1, 2...) pixels to each: so ask for what gives the
    // pixels wanted, whichever screen it is.
    double backing = [NSScreen mainScreen].backingScaleFactor;
    if (backing < 1.0) backing = 1.0;
    double scale = MIN((double)kPixelsPerPoint, (double)kMaxPixels / high);
    config.snapshotWidth = @(self.width * scale / backing);
    __weak WSJob *me = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WSJob *job = me;
        if (!job || job.finished) return;
        [job.view takeSnapshotWithConfiguration:config
                              completionHandler:^(NSImage *image, NSError *error) {
            WSJob *again = me;
            if (!again || again.finished) return;
            if (!image) {
                [again fail:error.localizedDescription ?: @"No snapshot"];
                return;
            }
            CGImageRef cg = [image CGImageForProposedRect:NULL context:nil hints:nil];
            if (!cg) { [again fail:@"No image"]; return; }
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
            NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSString *temp = [again.path stringByAppendingString:@".part"];
            if (![png writeToFile:temp atomically:NO]
                || rename(temp.fileSystemRepresentation, again.path.fileSystemRepresentation) != 0) {
                [again fail:@"The picture could not be written"];
                return;
            }
            again.finished = YES;
            strlcpy(titles[again.slot], again.view.title.UTF8String ?: "", WS_MESSAGE);
            finish(again.slot, WS_DONE, (int)CGImageGetHeight(cg), @"");
        }];
    });
}

@end

int ws_start(int slot, const char *url, const char *path, int width, int max_height)
{
    if (slot < 0 || slot >= WS_JOBS || states[slot] == WS_WORKING) return 0;
    [NSApplication sharedApplication];  // WebKit wants one; SDL's is this
    NSURL *target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    if (!target || !target.scheme) {
        states[slot] = WS_FAILED;
        strlcpy(messages[slot], "Not a link", WS_MESSAGE);
        return 1;
    }
    WSJob *job = [WSJob new];
    job.slot = slot;
    job.path = [NSString stringWithUTF8String:path];
    job.width = width;
    job.maxHeight = max_height;
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    job.view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, 900)
                                  configuration:config];
    job.view.navigationDelegate = job;
    jobs[slot] = job;
    states[slot] = WS_WORKING;
    titles[slot][0] = 0;
    phases[slot] = 0;
    messages[slot][0] = 0;
    if ([target isFileURL]) {
        [job.view loadFileURL:target allowingReadAccessToURL:[target URLByDeletingLastPathComponent]];
    } else {
        [job.view loadRequest:[NSURLRequest requestWithURL:target]];
    }
    __weak WSJob *me = job;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLoadTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WSJob *late = me;
        if (late && !late.finished) [late fail:@"Timed out"];
    });
    return 1;
}

void ws_pump(int milliseconds)
{
    [[NSRunLoop mainRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:milliseconds / 1000.0]];
}

int ws_state(int slot) { return slot >= 0 && slot < WS_JOBS ? states[slot] : WS_IDLE; }
int ws_height(int slot) { return slot >= 0 && slot < WS_JOBS ? heights[slot] : 0; }
const char *ws_message(int slot) { return slot >= 0 && slot < WS_JOBS ? messages[slot] : ""; }
// Percent done: the page's load is the first four fifths, then the wait
// for late layout, the measure and the snapshot.
int ws_progress(int slot)
{
    if (slot < 0 || slot >= WS_JOBS) return 0;
    if (states[slot] == WS_DONE) return 100;
    if (states[slot] != WS_WORKING) return 0;
    double done = phases[slot];
    WSJob *job = jobs[slot];
    if (job && done < 0.8) done = MAX(done, job.view.estimatedProgress * 0.8);
    return (int)(done * 100.0);
}
const char *ws_title(int slot) { return slot >= 0 && slot < WS_JOBS ? titles[slot] : ""; }
void ws_reset(int slot)
{
    if (slot < 0 || slot >= WS_JOBS) return;
    jobs[slot].finished = YES;
    jobs[slot] = nil;
    states[slot] = WS_IDLE;
    heights[slot] = 0;
    phases[slot] = 0;
    messages[slot][0] = 0;
    titles[slot][0] = 0;
}
