// Web search, by WebKit: an offscreen WKWebView per search loads
// DuckDuckGo's page of results, and a script reads the links out of it.
// Everything is on the main thread, which must be running its run loop
// (SDL's event pump does).

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#define WSR_JOBS 4
#define WSR_RESULTS 25
#define WSR_TITLE 160
#define WSR_URL 512
#define WSR_MESSAGE 160

enum { WSR_IDLE = 0, WSR_WORKING = 1, WSR_DONE = 2, WSR_FAILED = 3 };

static const NSTimeInterval kLoadTimeout = 30.0;

// DuckDuckGo's page without scripts: its results are in the HTML as
// loaded, so there is nothing to wait for after the load.
static NSString *const kSearchURL = @"https://html.duckduckgo.com/html/?q=";

// Reads the page's links as [{t: title, u: address}]. A result's link goes
// through DuckDuckGo's server (/l/?uddg=<address>) so the address is taken
// out of that. The second selector is for the page with scripts. With no
// links, the page may be DuckDuckGo's challenge ("bots use DuckDuckGo too",
// pictures of ducks to pick) and not a search with nothing found: blocked.
static NSString *const kReadScript =
    @"(function () {"
     "  var found = [];"
     "  var links = document.querySelectorAll("
     "    'a.result__a, a[data-testid=\"result-title-a\"]');"
     "  for (var i = 0; i < links.length; i++) {"
     "    var title = links[i].textContent.replace(/\\s+/g, ' ').trim();"
     "    var address = null;"
     "    try {"
     "      var url = new URL(links[i].getAttribute('href'), location.href);"
     "      var target = url.searchParams.get('uddg');"
     "      address = (/(^|\\.)duckduckgo\\.com$/.test(url.hostname)"
     "                 && url.pathname === '/l/' && target) ? target : url.href;"
     "    } catch (e) {}"
     "    if (title && address && /^https?:/.test(address))"
     "      found.push({t: title, u: address});"
     "  }"
     "  var blocked = found.length === 0 && ("
     "    document.querySelector('.anomaly-modal, #challenge-form, form[action*=\"anomaly\"]')"
     "    || /bots use DuckDuckGo|select all squares containing/i.test("
     "         document.body ? document.body.innerText : ''));"
     "  return {blocked: !!blocked, found: found};"
     "})()";

@class WSRJob;

static WSRJob *jobs[WSR_JOBS];
static int states[WSR_JOBS];
static int counts[WSR_JOBS];
// Told how a search ended: 1 if DuckDuckGo blocked it, 0 if it found its page.
// (A page read for a test reports too, so that the back-off can be tested.)
static void (*outcome_hook)(int);

static int blocked[WSR_JOBS];  // Failed because DuckDuckGo wants proof of a person
static char messages[WSR_JOBS][WSR_MESSAGE];
static char titles[WSR_JOBS][WSR_RESULTS][WSR_TITLE];
static char urls[WSR_JOBS][WSR_RESULTS][WSR_URL];

static void finish(int slot, int state, NSString *message)
{
    states[slot] = state;
    if (state != WSR_FAILED) blocked[slot] = 0;
    strlcpy(messages[slot], message.UTF8String ?: "", WSR_MESSAGE);
    jobs[slot] = nil;
}

@interface WSRJob : NSObject <WKNavigationDelegate>
@property int slot;
@property(strong) WKWebView *view;
@property BOOL finished;
@property BOOL report;  // tell outcome_hook how it ended
@property NSInteger status;  // of the main page's response, 0 if it has none
@end

@implementation WSRJob

- (void)fail:(NSString *)why
{
    if (self.finished) return;
    self.finished = YES;
    BOOL wasBlocked = blocked[self.slot];
    finish(self.slot, WSR_FAILED, why);
    if (wasBlocked && self.report && outcome_hook) outcome_hook(1);
}

- (void)block
{
    if (self.finished) return;
    blocked[self.slot] = 1;
    [self fail:@"DuckDuckGo wants proof of a person (captcha)"];
}

// DuckDuckGo answers a challenge page with 202, a refusal with 429 or 403.
- (void)webView:(WKWebView *)view decidePolicyForNavigationResponse:(WKNavigationResponse *)response
                                                   decisionHandler:(void (^)(WKNavigationResponsePolicy))handler
{
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response.response;
    if (response.forMainFrame && [http isKindOfClass:[NSHTTPURLResponse class]]) {
        self.status = http.statusCode;
        if (self.status == 429) {
            blocked[self.slot] = 1;
            [self fail:@"DuckDuckGo says too many searches (429)"];
        } else if (self.status >= 400) {
            [self fail:[NSString stringWithFormat:@"The server answered %ld", (long)self.status]];
        }
    }
    handler(self.finished ? WKNavigationResponsePolicyCancel : WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)nav
{
    __weak WSRJob *me = self;
    [self.view evaluateJavaScript:kReadScript completionHandler:^(id result, NSError *error) {
        WSRJob *job = me;
        if (!job || job.finished) return;
        if (![result isKindOfClass:[NSDictionary class]] || ![result[@"found"] isKindOfClass:[NSArray class]]) {
            [job fail:error.localizedDescription ?: @"The page could not be read"];
            return;
        }
        NSArray *found = result[@"found"];
        if (found.count == 0 && ([result[@"blocked"] boolValue] || job.status == 202)) {
            [job block];
            return;
        }
        int n = 0;
        for (id item in found) {
            if (n == WSR_RESULTS) break;
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSString *title = item[@"t"];
            NSString *address = item[@"u"];
            if (![title isKindOfClass:[NSString class]] || ![address isKindOfClass:[NSString class]]) continue;
            // An address cut short would go somewhere else: drop it.
            if ([address lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= WSR_URL) continue;
            strlcpy(urls[job.slot][n], address.UTF8String, WSR_URL);
            strlcpy(titles[job.slot][n], title.UTF8String, WSR_TITLE);
            n++;
        }
        job.finished = YES;
        counts[job.slot] = n;
        finish(job.slot, WSR_DONE, @"");
        if (job.report && outcome_hook) outcome_hook(0);
    }];
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

@end

static int begin(int slot, NSURL *target, BOOL report)
{
    if (slot < 0 || slot >= WSR_JOBS || states[slot] == WSR_WORKING) return 0;
    [NSApplication sharedApplication];  // WebKit wants one; SDL's is this
    states[slot] = WSR_WORKING;
    counts[slot] = 0;
    blocked[slot] = 0;
    messages[slot][0] = 0;
    if (!target || !target.scheme) {
        states[slot] = WSR_FAILED;
        strlcpy(messages[slot], "Not a link", WSR_MESSAGE);
        return 1;
    }
    WSRJob *job = [WSRJob new];
    job.slot = slot;
    job.report = report;
    // Nothing a search leaves behind (cookies, caches) is kept.
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    job.view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 1024, 900) configuration:config];
    job.view.navigationDelegate = job;
    jobs[slot] = job;
    if ([target isFileURL]) {
        [job.view loadFileURL:target allowingReadAccessToURL:[target URLByDeletingLastPathComponent]];
    } else {
        [job.view loadRequest:[NSURLRequest requestWithURL:target]];
    }
    __weak WSRJob *me = job;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLoadTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WSRJob *late = me;
        if (late && !late.finished) [late fail:@"Timed out"];
    });
    return 1;
}

int wsr_start(int slot, const char *query)
{
    // Everything but letters, digits and a few marks is escaped, so that
    // & + = # in a query are not taken for the URL's own.
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString:@"-._~"];
    NSString *escaped = [[NSString stringWithUTF8String:query]
        stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    return begin(slot, escaped ? [NSURL URLWithString:[kSearchURL stringByAppendingString:escaped]] : nil, YES);
}

int wsr_start_page(int slot, const char *url)
{
    return begin(slot, [NSURL URLWithString:[NSString stringWithUTF8String:url]], YES);
}

void wsr_set_hook(void (*hook)(int)) { outcome_hook = hook; }

void wsr_pump(int milliseconds)
{
    [[NSRunLoop mainRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:milliseconds / 1000.0]];
}

int wsr_state(int slot) { return slot >= 0 && slot < WSR_JOBS ? states[slot] : WSR_IDLE; }
int wsr_blocked(int slot) { return slot >= 0 && slot < WSR_JOBS ? blocked[slot] : 0; }
int wsr_count(int slot) { return slot >= 0 && slot < WSR_JOBS ? counts[slot] : 0; }
const char *wsr_message(int slot) { return slot >= 0 && slot < WSR_JOBS ? messages[slot] : ""; }
const char *wsr_title(int slot, int item)
{
    return slot >= 0 && slot < WSR_JOBS && item >= 0 && item < counts[slot] ? titles[slot][item] : "";
}
const char *wsr_url(int slot, int item)
{
    return slot >= 0 && slot < WSR_JOBS && item >= 0 && item < counts[slot] ? urls[slot][item] : "";
}
void wsr_reset(int slot)
{
    if (slot < 0 || slot >= WSR_JOBS) return;
    jobs[slot].finished = YES;
    jobs[slot] = nil;
    states[slot] = WSR_IDLE;
    counts[slot] = 0;
    blocked[slot] = 0;
    messages[slot][0] = 0;
}
