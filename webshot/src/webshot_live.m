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

@implementation WLDelegate

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
    if (view != live_view && view.title.length > 0) view.window.title = view.title;
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
        if (live_view == nil || live_view.hidden || event.window != live_window || !wl_has_focus()) return event;
        NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        if (flags != NSEventModifierFlagCommand) return event;
        NSString *letter = event.charactersIgnoringModifiers;
        if (letter.length != 1) return event;
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
    if (!NSEqualRects(live_view.frame, frame)) live_view.frame = frame;
}

void wl_set_hidden(int hidden)
{
    if (live_view == nil) return;
    live_view.hidden = hidden != 0;
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
