// A live browser view: one WKWebView that is a subview of an SDL window's
// content view, placed by the program each frame. Unlike the offscreen jobs
// of webshot_wk.m it keeps what the pages tell it (cookies and the rest, in
// WebKit's default store), so that a person can stay logged in.
//
// All of it is for the main thread, which SDL's event loop runs.

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

@interface WLDelegate : NSObject <WKUIDelegate, WKNavigationDelegate>
@end

static WKWebView *live_view;
static NSWindow *live_window;
static WLDelegate *live_delegate;
static id live_monitor;
static NSMutableArray<NSWindow *> *popups;

// Command with a letter that the program keeps for itself (see wl_keep): the page would take it, so it is
// caught on its way, and said in wl_shortcut.
#define KEPT 8
static int kept_letter[KEPT];
static int kept_number[KEPT];
static int kept_count;
static int pending_shortcut;

// Where the program last asked the view to be: while a capture has it taller and hidden, Place and Show only say.
static NSRect want_frame;
static BOOL want_hidden = YES;
static BOOL capturing;

// The brand colour the page gives itself (its theme-color), as 0xRRGGBB, or -1.
static int page_colour = -1;

// The capture of the whole page as it now is, written as strips (see wl_capture_start).
enum { CAP_IDLE, CAP_WORKING, CAP_DONE, CAP_FAILED };
static int cap_state;
static int cap_strips;
static char cap_title[4096];
static char cap_message[256];
static NSString *cap_path;
static const int kMaxStrips = 32;       // pictures a page is written as, at most
static const int kMaxPixels = 16384;    // pixels tall a picture is, at most: what a GPU texture can be
static const int kPixelsPerPoint = 2;
static const int kMaxPoints = 100000;   // points tall the view is made to take a page

static NSString *const kColourScript =
    @"(function(){var m=document.querySelector('meta[name=\"theme-color\"]');"
     "if(!m||!m.content)return -1;var c=document.createElement('canvas');c.width=c.height=1;"
     "var x=c.getContext('2d');x.fillStyle='#010203';x.fillStyle=m.content;"
     "if(x.fillStyle==='#010203'&&m.content.replace(/\\s/g,'').toLowerCase()!=='#010203')return -1;"
     "x.fillRect(0,0,1,1);var d=x.getImageData(0,0,1,1).data;return d[0]*65536+d[1]*256+d[2];})()";

// Which sites the pages may be of (see wl_set_filter): 0 any, 1 all but the hosts listed, 2 only the hosts listed.
static int filter_mode;
static NSArray<NSString *> *filter_hosts;

// Whether a page at this address may be opened: only web addresses are held back, and a host is the listed one's
// or a subdomain of it.
static BOOL filter_permits(NSURL *url)
{
    NSString *scheme = url.scheme.lowercaseString;
    if (filter_mode == 0 || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) return YES;
    NSString *host = url.host.lowercaseString;
    BOOL listed = NO;
    for (NSString *site in filter_hosts) {
        if ([host isEqualToString:site] || [host hasSuffix:[@"." stringByAppendingString:site]]) {
            listed = YES;
            break;
        }
    }
    return filter_mode == 1 ? !listed : listed;
}

static NSString *html_escaped(NSString *text)
{
    text = [text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    text = [text stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    return [text stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
}

@implementation WLDelegate

// A page the filter holds back is not opened: the view says so in its place, so that it is not left showing a
// page that was not asked for. A link that opens a window of its own is held back too (it is the same view's).
- (void)webView:(WKWebView *)view
    decidePolicyForNavigationAction:(WKNavigationAction *)action
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = action.request.URL;
    if (!action.targetFrame.mainFrame && action.targetFrame != nil) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    if (filter_permits(url)) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    decisionHandler(WKNavigationActionPolicyCancel);
    NSString *page = [NSString
        stringWithFormat:@"<!doctype html><meta charset=utf-8><meta name=color-scheme content=\"light dark\">"
                          "<body style=\"font:15px -apple-system;margin:3em 2em;color:gray\">"
                          "<p><b>This site is not allowed.</b></p><p>%@</p><p>The site filter in the settings "
                          "decides which sites the browser opens.</p>",
                         html_escaped(url.host ?: url.absoluteString)];
    dispatch_async(dispatch_get_main_queue(), ^{ [view loadHTMLString:page baseURL:nil]; });
}

// A page that asks for a window of its own (window.open, as the sign-in of Google and others does, which
// talks to the page that opened it and closes itself when done) is given one: a window beside the program's,
// with the configuration it was handed, which is what keeps it joined to the page that opened it. A plain link
// that names no frame (target=_blank) is the same page's, and is followed here.
- (WKWebView *)webView:(WKWebView *)view
    createWebViewWithConfiguration:(WKWebViewConfiguration *)config
               forNavigationAction:(WKNavigationAction *)action
                    windowFeatures:(WKWindowFeatures *)features
{
    if (!action.targetFrame && !features.width && !features.height && action.navigationType == WKNavigationTypeLinkActivated) {
        [view loadRequest:action.request];
        return nil;
    }
    CGFloat width = features.width ? features.width.doubleValue : 520;
    CGFloat height = features.height ? features.height.doubleValue : 680;
    NSRect over = live_window.frame;
    NSRect frame = NSMakeRect(NSMidX(over) - width / 2, NSMidY(over) - height / 2, width, height);
    NSWindow *popup = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable |
                            NSWindowStyleMaskMiniaturizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    popup.releasedWhenClosed = NO;
    WKWebView *page = [[WKWebView alloc] initWithFrame:((NSView *)popup.contentView).bounds configuration:config];
    page.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    page.UIDelegate = self;
    page.navigationDelegate = self;
    [popup.contentView addSubview:page];
    if (popups == nil) popups = [NSMutableArray new];
    [popups addObject:popup];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification
                                                      object:popup
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
        [popups removeObject:popup];
    }];
    [popup makeKeyAndOrderFront:nil];
    return page;
}

// The page that was opened asks to be closed (window.close).
- (void)webViewDidClose:(WKWebView *)view
{
    if (view != live_view) [view.window close];
}

// A window of its own is named for the page in it.
- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)navigation
{
    if (view != live_view) {
        if (view.title.length > 0) view.window.title = view.title;
        return;
    }
    [view evaluateJavaScript:kColourScript completionHandler:^(id result, NSError *error) {
        page_colour = [result isKindOfClass:[NSNumber class]] ? [result intValue] : -1;
    }];
}

- (void)webView:(WKWebView *)view didCommitNavigation:(WKNavigation *)navigation
{
    if (view == live_view) page_colour = -1;
}

@end

int wl_has_focus(void);

int wl_attach(void *window)
{
    if (live_view != nil) return 1;
    live_window = (__bridge NSWindow *)window;
    if (live_window == nil) return 0;
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    // Some sign-in pages turn away a browser that does not say it is Safari.
    config.applicationNameForUserAgent = @"Version/17.5 Safari/605.1.15";
    config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    live_view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100) configuration:config];
    live_delegate = [WLDelegate new];
    live_view.UIDelegate = live_delegate;
    live_view.navigationDelegate = live_delegate;
    live_view.autoresizingMask = NSViewNotSizable;
    [live_window.contentView addSubview:live_view];
    live_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                         handler:^NSEvent *(NSEvent *event) {
        if (live_view == nil) return event;
        BOOL popup = event.window != nil && [popups containsObject:event.window];
        if (!popup && (live_view.hidden || event.window != live_window || !wl_has_focus())) return event;
        NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        NSString *letter = event.charactersIgnoringModifiers;
        if (letter.length != 1) return event;
        // The Edit menu's Command-Z X C V A would reach the program's own text, not the page that has the
        // keyboard (nor that of a window the page opened), so they are put to the page here.
        BOOL shifted = flags == (NSEventModifierFlagCommand | NSEventModifierFlagShift);
        if (flags == NSEventModifierFlagCommand || shifted) {
            SEL action = NULL;
            switch ([letter.lowercaseString characterAtIndex:0]) {
            case 'x': action = shifted ? NULL : @selector(cut:); break;
            case 'c': action = shifted ? NULL : @selector(copy:); break;
            case 'v': action = shifted ? NULL : @selector(paste:); break;
            case 'a': action = shifted ? NULL : @selector(selectAll:); break;
            case 'z': {
                NSUndoManager *undo = [event.window.firstResponder undoManager];
                if (undo == nil) undo = event.window.undoManager;
                if (shifted) [undo redo]; else [undo undo];
                return nil;
            }
            }
            if (action != NULL) {
                [NSApp sendAction:action to:nil from:nil];
                return nil;
            }
        }
        if (popup || flags != NSEventModifierFlagCommand) return event;
        for (int i = 0; i < kept_count; i++) {
            if ([letter characterAtIndex:0] == (unichar)kept_letter[i]) {
                pending_shortcut = kept_number[i];
                return nil;
            }
        }
        return event;
    }];
    return 1;
}

void wl_detach(void)
{
    for (NSWindow *popup in [popups copy]) [popup close];
    if (live_monitor != nil) [NSEvent removeMonitor:live_monitor];
    live_monitor = nil;
    [live_view removeFromSuperview];
    live_view = nil;
    live_window = nil;
}

// Place the view: points from the content's top left, as the program lays out.
void wl_set_frame(double x, double y, double w, double h)
{
    if (live_view == nil) return;
    NSView *content = live_window.contentView;
    double top = content.isFlipped ? y : content.bounds.size.height - y - h;
    NSRect frame = NSMakeRect(x, top, w, h);
    want_frame = frame;
    if (capturing) return;
    if (!NSEqualRects(live_view.frame, frame)) live_view.frame = frame;
}

void wl_set_hidden(int hidden)
{
    if (live_view == nil) return;
    want_hidden = hidden != 0;
    if (capturing) return;
    live_view.hidden = want_hidden;
}

// Hold back the pages of some sites (see filter_mode): hosts is one lower-case host to a line.
void wl_set_filter(int mode, const char *hosts)
{
    filter_mode = mode;
    NSString *all = [NSString stringWithUTF8String:hosts ?: ""];
    NSMutableArray<NSString *> *sites = [NSMutableArray new];
    for (NSString *line in [all componentsSeparatedByString:@"\n"]) {
        if (line.length > 0) [sites addObject:line.lowercaseString];
    }
    filter_hosts = sites;
}

void wl_load(const char *url)
{
    if (live_view == nil) return;
    NSURL *target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    if (target != nil) [live_view loadRequest:[NSURLRequest requestWithURL:target]];
}

// Give the keyboard to the page, or take it back for the program.
void wl_focus(int page)
{
    if (live_view == nil) return;
    [live_window makeFirstResponder:page ? live_view : live_window.contentView];
}

int wl_has_focus(void)
{
    if (live_view == nil) return 0;
    NSResponder *first = live_window.firstResponder;
    return [first isKindOfClass:[NSView class]] && [(NSView *)first isDescendantOf:live_view];
}

void wl_back(void) { [live_view goBack]; }
void wl_forward(void) { [live_view goForward]; }
void wl_reload(void) { [live_view reload]; }
void wl_stop(void) { [live_view stopLoading]; }

int wl_can_back(void) { return live_view.canGoBack; }
int wl_can_forward(void) { return live_view.canGoForward; }
int wl_loading(void) { return live_view.loading; }

// 0 .. 1000
int wl_progress(void) { return (int)(live_view.estimatedProgress * 1000); }

// Copy a string into the caller's buffer, cut at a character, and say its length.
static int give(NSString *text, char *buffer, int capacity)
{
    if (text == nil || capacity <= 0) return 0;
    NSUInteger used = 0;
    if (![text getBytes:buffer maxLength:(NSUInteger)capacity - 1 usedLength:&used encoding:NSUTF8StringEncoding
                options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, text.length)
         remainingRange:NULL])
        return 0;
    buffer[used] = 0;
    return (int)used;
}

int wl_title(char *buffer, int capacity) { return give(live_view.title, buffer, capacity); }
int wl_url(char *buffer, int capacity) { return give(live_view.URL.absoluteString, buffer, capacity); }

// Keep Command with this letter for the program while the page has the keyboard, as number 1 .. KEPT.
void wl_keep(int letter, int number)
{
    if (kept_count < KEPT) {
        kept_letter[kept_count] = letter;
        kept_number[kept_count] = number;
        kept_count++;
    }
}

// Which kept shortcut was pressed since this was last called: its number, or 0.
int wl_shortcut(void)
{
    int number = pending_shortcut;
    pending_shortcut = 0;
    return number;
}

int wl_page_colour(void) { return page_colour; }

// The capture ---------------------------------------------------------------------------------------------

// The name of the picture of a strip: the first is the file asked for, the others are beside it, as stem.2.png.
static NSString *strip_name(int index)
{
    if (index == 1) return cap_path;
    return [[cap_path stringByDeletingPathExtension] stringByAppendingFormat:@".%d.png", index];
}

static void cap_end(int state, NSString *message)
{
    capturing = NO;
    if (live_view != nil) {
        live_view.frame = want_frame;
        live_view.hidden = want_hidden;
    }
    if (message != nil) strlcpy(cap_message, message.UTF8String, sizeof cap_message);
    cap_state = state;
}

static void cap_strip(int index, int high, double scale, int points)
{
    int offset = (index - 1) * points;
    if (live_view == nil) { cap_end(CAP_FAILED, @"The page is gone"); return; }
    if (offset >= high) { cap_end(CAP_DONE, nil); return; }
    WKSnapshotConfiguration *config = [WKSnapshotConfiguration new];
    double width = live_view.frame.size.width;
    config.rect = NSMakeRect(0, offset, width, MIN(points, high - offset));
    double backing = [NSScreen mainScreen].backingScaleFactor;
    if (backing < 1.0) backing = 1.0;
    config.snapshotWidth = @(width * scale / backing);
    [live_view takeSnapshotWithConfiguration:config completionHandler:^(NSImage *image, NSError *error) {
        CGImageRef cg = image ? [image CGImageForProposedRect:NULL context:nil hints:nil] : NULL;
        if (!cg) { cap_end(CAP_FAILED, error.localizedDescription ?: @"No snapshot"); return; }
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *name = strip_name(index);
        NSString *temp = [name stringByAppendingString:@".part"];
        if (![png writeToFile:temp atomically:NO]
            || rename(temp.fileSystemRepresentation, name.fileSystemRepresentation) != 0) {
            cap_end(CAP_FAILED, @"The picture could not be written");
            return;
        }
        cap_strips = index;
        cap_strip(index + 1, high, scale, points);
    }];
}

// Take the whole of the page, one picture under another, as the strips of a page that a job of webshot.m takes:
// but of the page as it is, with what the person has done to it. The view is hidden and made as tall as the
// page while it is done, and as it was after.
int wl_capture_start(const char *path)
{
    if (live_view == nil || cap_state == CAP_WORKING) return 0;
    cap_state = CAP_WORKING;
    cap_strips = 0;
    cap_message[0] = 0;
    cap_path = [NSString stringWithUTF8String:path];
    strlcpy(cap_title, live_view.title.UTF8String ?: "", sizeof cap_title);
    capturing = YES;
    live_view.hidden = YES;
    // The page's height; or, for one that scrolls inside a box of its own (as many apps do) and not as a whole,
    // the tallest such box's, which is as tall as the page is to be made for the box to show it all.
    [live_view evaluateJavaScript:@"(function(){var h=Math.max(document.documentElement.scrollHeight,"
                                   "document.body?document.body.scrollHeight:0);"
                                   "if(h<=window.innerHeight+1){var all=document.querySelectorAll('*');"
                                   "for(var i=0;i<all.length;i++){var e=all[i];var o=getComputedStyle(e).overflowY;"
                                   "if((o==='auto'||o==='scroll')&&e.scrollHeight>e.clientHeight+1){"
                                   "h=Math.max(h,window.innerHeight+e.scrollHeight-e.clientHeight);}}}"
                                   "return h;})()"
                completionHandler:^(id result, NSError *error) {
        if (live_view == nil) { cap_end(CAP_FAILED, @"The page is gone"); return; }
        int high = [result isKindOfClass:[NSNumber class]] ? [result intValue] : 0;
        high = MIN(kMaxPoints, MAX(high, (int)ceil(want_frame.size.height)));
        double scale = MIN((double)kPixelsPerPoint, (double)kMaxStrips * kMaxPixels / high);
        int points = MAX(1, (int)floor(kMaxPixels / scale));
        live_view.frame = NSMakeRect(want_frame.origin.x, want_frame.origin.y, want_frame.size.width, high);
        // What a longer page left beside the file is not part of this one.
        for (int old = 2; [[NSFileManager defaultManager] fileExistsAtPath:strip_name(old)]; old++)
            [[NSFileManager defaultManager] removeItemAtPath:strip_name(old) error:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            cap_strip(1, high, scale, points);
        });
    }];
    return 1;
}

int wl_capture_state(void) { return cap_state; }
int wl_capture_strips(void) { return cap_strips; }
int wl_capture_title(char *buffer, int capacity)
{
    return give([NSString stringWithUTF8String:cap_title], buffer, capacity);
}
int wl_capture_message(char *buffer, int capacity)
{
    return give([NSString stringWithUTF8String:cap_message], buffer, capacity);
}
void wl_capture_reset(void) { if (cap_state != CAP_WORKING) cap_state = CAP_IDLE; }
