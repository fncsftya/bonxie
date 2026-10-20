// Pictures of web pages, by WebKit: an offscreen WKWebView per job loads
// the page, and its snapshot is written as a PNG. Everything is on the
// main thread, which must be running its run loop (SDL's event pump does).

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#define WS_MESSAGE 160

#define WS_URL 512

enum { WS_IDLE = 0, WS_WORKING = 1, WS_DONE = 2, WS_FAILED = 3, WS_LOOKED = 4 };

static const NSTimeInterval kLoadTimeout = 45.0;
static const int kPixelsPerPoint = 2;
static const int kMaxPixels = 16384;  // a texture's side, at most
static const NSTimeInterval kSettle = 0.6;  // after load, for late layout
static const NSTimeInterval kBannerWait = 1.0;  // after a click, for the banner to go
static const int kBannerRounds = 2;  // a banner may lead to another notice
static const int kMaxFrames = 8;
static const int kLookHeight = 1024;  // points, of the window the page is first seen in, and of a screen
// (tall enough for a notice to be all in one: a notice cut across two screens is hard to read)
static const int kTileCount = 4;  // screens of the top of a page that are also written, if asked for

// (What costs something or takes the reader away, as a button to subscribe, to pay or to sign
// in, is never pressed, whatever it is asked for.)
//
// Presses the button of a notice that says what is wanted (a label a person, or a
// program reading a picture of the page, has given), and answers whether it did. What
// is read in a picture may be a little wrong, so a label that is not found as it is
// is looked for as the start of one, as part of one, and with a letter wrong. The
// page's open shadow roots are searched, and so are the frames, by running it in each.
// The wanted label is the one argument: see ws_press.
static NSString *const kPressScript =
    @"(function (wanted) {"
     "  function plain(t) {"
     "    return (t || '').toLowerCase().replace(/[^\\p{L}\\p{N}]+/gu, ' ').trim();"
     "  }"
     "  function apart(a, b, most) {"
     "    if (Math.abs(a.length - b.length) > most) return most + 1;"
     "    var row = [];"
     "    for (var j = 0; j <= b.length; j++) row.push(j);"
     "    for (var i = 1; i <= a.length; i++) {"
     "      var last = row[0]; row[0] = i;"
     "      for (var k = 1; k <= b.length; k++) {"
     "        var up = row[k];"
     "        row[k] = Math.min(row[k] + 1, row[k - 1] + 1, last + (a[i - 1] === b[k - 1] ? 0 : 1));"
     "        last = up;"
     "      }"
     "    }"
     "    return row[b.length];"
     "  }"
     "  function roots(from, found) {"
     "    found.push(from);"
     "    var all = from.querySelectorAll('*');"
     "    for (var i = 0; i < all.length; i++)"
     "      if (all[i].shadowRoot) roots(all[i].shadowRoot, found);"
     "    return found;"
     "  }"
     "  function shown(el) {"
     "    var box = el.getBoundingClientRect();"
     "    if (box.width < 4 || box.height < 4) return false;"
     "    var style = getComputedStyle(el);"
     "    return style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0';"
     "  }"
     "  var want = plain(wanted);"
     "  if (!want) return false;"
     "  var refused = /subscri|\\bpay\\b|\\bbuy\\b|purchas|checkout|\\bsign ?in\\b|\\blog ?in\\b|\\bregister\\b|"
     "\\bjoin\\b|\\bdonat|\\bsupport us\\b|[£$€]\\s?\\d|\\d\\s?(£|\\$|€)/i;"
     "  var best = null, bestRank = 0, bestSize = 1e9;"
     "  var spots = roots(document, []);"
     "  for (var s = 0; s < spots.length; s++) {"
     "    var all = spots[s].querySelectorAll("
     "      'button, a, [role=button], [role=link], input[type=button], input[type=submit], summary, label, "
     "[onclick], [tabindex], span, div, p');"
     "    for (var i = 0; i < all.length; i++) {"
     "      var el = all[i];"
     "      var own = el.innerText || el.value || el.getAttribute('aria-label') || el.title || '';"
     "      if (own.length > 120) continue;"
     "      var text = plain(own);"
     "      if (!text || !shown(el) || refused.test(own)) continue;"
     "      var clickable = el.matches('button, a, [role=button], [role=link], input, summary, label, [onclick], "
     "[tabindex]') || getComputedStyle(el).cursor === 'pointer';"
     "      if (!clickable) continue;"
     "      var rank = text === want ? 4 : (text.indexOf(want) === 0 || want.indexOf(text) === 0 && text.length > 3"
     "        ? 3 : (text.indexOf(want) >= 0 ? 2 : (apart(text, want, 1 + (want.length >> 3)) <= 1 + (want.length >> 3)"
     "        ? 1 : 0)));"
     "      if (rank > bestRank || (rank === bestRank && rank > 0 && text.length < bestSize)) {"
     "        best = el; bestRank = rank; bestSize = text.length;"
     "      }"
     "    }"
     "  }"
     "  if (!best) return false;"
     "  var names = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];"
     "  for (var n = 0; n < names.length; n++)"
     "    best.dispatchEvent(new MouseEvent(names[n], {bubbles: true, cancelable: true, view: window}));"
     "  return true;"
     "})";

// Whether a notice about cookies covers the page now (1), or one of the common
// consent tools is in the page and not yet shown (2), as these are put up a
// moment after the page has loaded; or none (0).
static NSString *const kNoticeScript =
    @"(function () {"
     "  var about = /cookie|consent|privacy|tracking|gdpr|partners/i;"
     "  var named = /cookie|consent|gdpr|cmp|onetrust|didomi|truste|cookiebot|sp_message|usercentrics|osano|"
     "iubenda|quantcast/i;"
     "  var tool = /cookiebot|onetrust|didomi|usercentrics|sp_message|truste|osano|iubenda|quantcast/i;"
     "  var pending = false;"
     "  var all = document.querySelectorAll('div, section, aside, dialog, [role=dialog]');"
     "  for (var i = 0; i < all.length; i++) {"
     "    var el = all[i];"
     "    var label = (el.id || '') + ' ' + (typeof el.className === 'string' ? el.className : '');"
     "    var style = getComputedStyle(el);"
     "    var covering = style.position === 'fixed' || style.position === 'sticky' ||"
     "      el.getAttribute('role') === 'dialog' || el.tagName === 'DIALOG';"
     "    if (!covering && !named.test(label)) continue;"
     "    var box = el.getBoundingClientRect();"
     "    var visible = box.width > 40 && box.height > 40 && style.visibility !== 'hidden' &&"
     "      style.display !== 'none' && style.opacity !== '0';"
     "    if (!visible) { if (tool.test(label)) pending = true; continue; }"
     "    var text = el.innerText || '';"
     "    if (text.length < 4000 && about.test(text) &&"
     "        el.querySelector('button, a, [role=button], input[type=button]')) return 1;"
     "  }"
     "  return pending ? 2 : 0;"
     "})()";

// (Else a link to a PDF that is labelled so, as PDF, Download PDF, View PDF or PDF/ePub, if the
// page has only one such, as the front of a paper has: a page that lists many is no front.)
//
// The address of the PDF a page says it is the page of, as most journals and
// repositories do (citation_pdf_url, for scholars' indexes): "" if it says none.
static NSString *const kDocumentScript =
    @"(function () {"
     "  var meta = document.querySelector('meta[name=\"citation_pdf_url\"], meta[name=\"eprints.document_url\"]');"
     "  try {"
     "    if (meta && meta.content) return new URL(meta.content, location.href).href;"
     "    var link = document.querySelector('link[rel=\"alternate\"][type=\"application/pdf\"]');"
     "    if (link && link.href) return link.href;"
     "  } catch (e) {}"
     "  var label = /^(download |view |get |full[- ]?text )?pdf\\b|\\bpdf ?\\/ ?e/i;"
     "  var shape = /\\.pdf($|[?#])|\\/e?pdf(plus)?\\//i;"
     "  function key(h) { return h.split(/[?#]/)[0].replace(/\\/e?pdf(plus)?\\//, '/pdf/'); }"
     "  var links = document.querySelectorAll('a[href]');"
     "  var found = {}, count = 0, first = '', direct = '';"
     "  for (var i = 0; i < links.length; i++) {"
     "    var text = (links[i].innerText || links[i].getAttribute('aria-label') || links[i].title || '').trim();"
     "    if (text.length > 40 || !label.test(text)) continue;"
     "    var href;"
     "    try { href = new URL(links[i].getAttribute('href'), location.href).href; } catch (e) { continue; }"
     "    if (!/^(https?|file):/.test(href) || !shape.test(href)) continue;"
     "    if (!found[key(href)]) { found[key(href)] = true; count++; first = first || href; }"
     "    if (!direct && !/\\/(e|plus)/.test(href.replace(/^[a-z]+:\\/\\/[^\\/]+/, '')) && /\\/pdf\\//.test(href)) direct = href;"
     "  }"
     "  return count === 1 ? (direct || first) : '';"
     "})()";

// Clicks away a cookie banner or like notice that covers the page, if there is
// one, and answers whether it did. A button counts only if it is in what looks
// like such a notice (a dialog, something fixed over the page, or named for
// cookies or consent) that says as much, and its label is one of a few. Cookies are
// accepted, as the page is read in a window that keeps nothing: a button that accepts
// is pressed in preference to one that rejects or keeps to what is necessary, which
// often leads to a page of choices, not to the page. The page's open shadow roots are searched
// too, as some banners are kept in one; those of other frames are, by running it
// in each frame, where a document that is about cookies as a whole is the notice (what
// is fixed over the page is the frame itself, in the page).
static NSString *const kDismissScript =
    @"(function () {"
     "  var reject = /^(reject|decline|deny|refuse|disagree|no thanks|no, thanks|only (strictly )?necessary|"
     "necessary only|essential only|use necessary|continue without (accepting|agreeing)|"
     "(save|confirm) (my )?(choices|preferences|settings))\\b/i;"
     "  var accept = /^(accept|allow|agree|i agree|i accept|i understand|got it|ok|okay|yes, i agree|"
     "consent|continue|close|dismiss|understood)\\b/i;"
     "  var named = /cookie|consent|gdpr|privacy|cmp|onetrust|didomi|truste|cookiebot|sp_message|"
     "usercentrics|osano|iubenda|quantcast|banner|notice/i;"
     "  var about = /cookie|consent|privacy|tracking|gdpr|personal data|partners/i;"
     "  var known = ['#onetrust-accept-btn-handler', '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll',"
     "    '#didomi-notice-agree-button', 'button[data-testid=\\\"uc-accept-all-button\\\"]',"
     "    '#truste-consent-button', '.fc-cta-consent', '.sp_choice_type_11', '.cc-allow', '.cc-dismiss',"
     "    '#onetrust-reject-all-handler', '#CybotCookiebotDialogBodyButtonDecline',"
     "    '#didomi-notice-disagree-button', 'button[data-testid=\\\"uc-deny-all-button\\\"]'];"
     "  function roots(from, found) {"
     "    found.push(from);"
     "    var all = from.querySelectorAll('*');"
     "    for (var i = 0; i < all.length; i++)"
     "      if (all[i].shadowRoot) roots(all[i].shadowRoot, found);"
     "    return found;"
     "  }"
     "  function shown(el) {"
     "    var box = el.getBoundingClientRect();"
     "    if (box.width < 4 || box.height < 4) return false;"
     "    var style = getComputedStyle(el);"
     "    return style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0';"
     "  }"
     "  function noticeOf(el) {"
     "    for (var up = el, depth = 0; up && depth < 10; up = up.parentNode || up.host, depth++) {"
     "      if (up.nodeType !== 1) continue;"
     "      var style = getComputedStyle(up);"
     "      var covering = style.position === 'fixed' || style.position === 'sticky';"
     "      var dialog = up.getAttribute('role') === 'dialog' || up.getAttribute('role') === 'alertdialog'"
     "        || up.getAttribute('aria-modal') === 'true';"
     "      var label = (up.id || '') + ' ' + (up.className && up.className.baseVal === undefined ? up.className : '')"
     "        + ' ' + (up.getAttribute('aria-label') || '');"
     "      if ((covering || dialog || named.test(label)) && about.test(up.innerText || '')"
     "          && (up.innerText || '').length < 4000) return up;"
     "    }"
     "    var own = document.body ? document.body.innerText || '' : '';"
     "    return (window.top !== window && about.test(own) && own.length < 4000) ? document.body : null;"
     "  }"
     "  var spots = roots(document, []);"
     "  for (var k = 0; k < known.length; k++) {"
     "    for (var r = 0; r < spots.length; r++) {"
     "      var hit = spots[r].querySelector(known[k]);"
     "      if (hit && shown(hit)) { hit.click(); return true; }"
     "    }"
     "  }"
     "  var best = null, wanted = 0;"
     "  for (var s = 0; s < spots.length; s++) {"
     "    var buttons = spots[s].querySelectorAll("
     "      'button, a, [role=button], input[type=button], input[type=submit], [tabindex]');"
     "    for (var i = 0; i < buttons.length; i++) {"
     "      var b = buttons[i];"
     "      var label = (b.innerText || b.value || b.getAttribute('aria-label') || '').trim();"
     "      if (label.length < 2 || label.length > 40 || !shown(b)) continue;"
     "      var rank = accept.test(label) ? 2 : (reject.test(label) ? 1 : 0);"
     "      if (rank > wanted && noticeOf(b)) { best = b; wanted = rank; }"
     "    }"
     "  }"
     "  if (best) { best.click(); return true; }"
     "  return false;"
     "})()";

@class WSJob;

// What is kept of each job, in the slot it is given. A slot is made when a job is first
// begun in it, so there is no number of them it stops at.
typedef struct {
    int state;
    int height;
    double phase;  // how far on, 0..1, once the page is loaded
    char message[WS_MESSAGE];
    char title[WS_MESSAGE];  // of the page, once Done or Looked
    char document[WS_URL];  // of the PDF the page is of, once Looked
    int pressed;  // whether the last press found a button
    int tile_count;  // screens written beside the whole page, once Done
} WSSlot;

static WSSlot **slot_table;
static int slot_count;
static NSMutableArray *job_table;  // a WSJob, or NSNull where there is none
static WSSlot empty_slot;  // what a slot not made is: never written

static WSSlot *slot_data(int slot)
{
    return slot >= 0 && slot < slot_count ? slot_table[slot] : &empty_slot;
}

static void ensure_slot(int slot)
{
    if (slot < slot_count) return;
    int count = MAX(slot + 1, slot_count * 2);
    slot_table = realloc(slot_table, sizeof(WSSlot *) * count);
    if (!job_table) job_table = [NSMutableArray new];
    for (int index = slot_count; index < count; index++) {
        slot_table[index] = calloc(1, sizeof(WSSlot));
        [job_table addObject:[NSNull null]];
    }
    slot_count = count;
}

static WSJob *job_of(int slot)
{
    if (slot < 0 || slot >= slot_count) return nil;
    id job = job_table[slot];
    return job == [NSNull null] ? nil : job;
}

static void set_job(int slot, WSJob *job)
{
    job_table[slot] = job ?: (id)[NSNull null];
}

static void finish(int slot, int state, int height, NSString *message)
{
    slot_data(slot)->state = state;
    slot_data(slot)->height = height;
    strlcpy(slot_data(slot)->message, message.UTF8String ?: "", WS_MESSAGE);
    set_job(slot, nil);
}

@interface WSJob : NSObject <WKNavigationDelegate, WKDownloadDelegate>
@property int slot;
@property(strong) WKWebView *view;
@property(copy) NSString *path;
@property int width;
@property BOOL finished;
@property BOOL loaded;  // the page has been loaded
@property BOOL proceeded;  // it has been gone on with, once: a page may finish loading again
@property BOOL rechecked;  // it has been looked at again, for a notice that came late
@property(copy) NSString *fetchPath;  // where a file the address is of is to be put, if it is to be fetched
@property(strong) WKDownload *download;  // the file, on its way
@property BOOL dismiss;  // click away banners the page's own way
@property(copy) NSString *lookPath;  // the picture of the top of the page, or nil for none
@property(copy) NSString *tilePrefix;  // where the first screens of the page are written, or nil for none
@property(strong) NSMutableArray<WKFrameInfo *> *frames;  // of the page's frames inside it
@end

@implementation WSJob

- (void)fail:(NSString *)why
{
    if (self.finished) return;
    self.finished = YES;
    finish(self.slot, WS_FAILED, 0, why);
}

// Of a job that is to fetch a file: a response that is one (a PDF, or what the server says is
// to be saved) is downloaded; a page is let load, as it may be one that asks the browser to
// show it is a person, and sends it on to the file when it has.
- (void)webView:(WKWebView *)view decidePolicyForNavigationResponse:(WKNavigationResponse *)response
                                                    decisionHandler:(void (^)(WKNavigationResponsePolicy))handler
{
    if (self.fetchPath && !self.finished) {
        NSString *type = response.response.MIMEType.lowercaseString ?: @"";
        NSString *how = @"";
        if ([response.response isKindOfClass:[NSHTTPURLResponse class]])
            how = [((NSHTTPURLResponse *)response.response).allHeaderFields[@"Content-Disposition"] description].lowercaseString ?: @"";
        if ([type isEqualToString:@"application/pdf"] || [type isEqualToString:@"application/octet-stream"]
            || [how hasPrefix:@"attachment"]) {
            handler(WKNavigationResponsePolicyDownload);
            return;
        }
    }
    handler(WKNavigationResponsePolicyAllow);
}

// A response that is a file to be had: the download is ours to follow.
- (void)webView:(WKWebView *)view navigationResponse:(WKNavigationResponse *)response
                                    didBecomeDownload:(WKDownload *)download
{
    self.download = download;
    download.delegate = self;
}

- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response
                                                     suggestedFilename:(NSString *)name
                                                     completionHandler:(void (^)(NSURL *))handler
{
    NSString *temp = [self.fetchPath stringByAppendingString:@".part"];
    [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
    handler([NSURL fileURLWithPath:temp]);
}

- (void)downloadDidFinish:(WKDownload *)download
{
    if (self.finished) return;
    NSString *temp = [self.fetchPath stringByAppendingString:@".part"];
    if (rename(temp.fileSystemRepresentation, self.fetchPath.fileSystemRepresentation) != 0) {
        [self fail:@"The file could not be written"];
        return;
    }
    self.finished = YES;
    finish(self.slot, WS_DONE, 0, @"");
}

- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData
{
    [self fail:error.localizedDescription ?: @"The file could not be had"];
}

- (void)webView:(WKWebView *)view didFinishNavigation:(WKNavigation *)nav
{
    if (self.fetchPath) {
        // A page that is no file: it may send the browser on to one in a moment (when it has
        // seen it is a person); if it has not, it was no file.
        __weak WSJob *me = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WSJob *job = me;
            if (job && !job.download && !job.finished) [job fail:@"Not a file"];
        });
        return;
    }
    if (self.proceeded) return;
    self.proceeded = YES;
    slot_data(self.slot)->phase = 0.8;
    self.loaded = YES;
    __weak WSJob *me = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSettle * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (me.dismiss) [me dismissBanners:1]; else [me proceed];
    });
}

// The page is ready to be taken: the top of it to be looked at first, if that is
// asked for, and else the whole of it.
- (void)proceed
{
    if (self.lookPath) [self look]; else [self measure];
}

// The picture of the top of the page, as it is seen in a window, is made, and the
// job waits to be told what to do (press a button, or go on).
- (void)look
{
    if (self.finished) return;
    slot_data(self.slot)->phase = 0.85;
    WKSnapshotConfiguration *config = [WKSnapshotConfiguration new];
    config.rect = NSMakeRect(0, 0, self.width, kLookHeight);
    double backing = [NSScreen mainScreen].backingScaleFactor;
    if (backing < 1.0) backing = 1.0;
    config.snapshotWidth = @(self.width * kPixelsPerPoint / backing);
    __weak WSJob *me = self;
    [self.view takeSnapshotWithConfiguration:config completionHandler:^(NSImage *image, NSError *error) {
        WSJob *job = me;
        if (!job || job.finished) return;
        CGImageRef cg = image ? [image CGImageForProposedRect:NULL context:nil hints:nil] : NULL;
        if (!cg) { [job fail:error.localizedDescription ?: @"No snapshot"]; return; }
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *temp = [job.lookPath stringByAppendingString:@".part"];
        if (![png writeToFile:temp atomically:NO]
            || rename(temp.fileSystemRepresentation, job.lookPath.fileSystemRepresentation) != 0) {
            [job fail:@"The picture could not be written"];
            return;
        }
        strlcpy(slot_data(job.slot)->title, job.view.title.UTF8String ?: "", WS_MESSAGE);
        [job.view evaluateJavaScript:kDocumentScript completionHandler:^(id result, NSError *err) {
            WSJob *again = me;
            if (!again || again.finished) return;
            strlcpy(slot_data(again.slot)->document, [result isKindOfClass:[NSString class]] ? [result UTF8String] : "", WS_URL);
            slot_data(again.slot)->state = WS_LOOKED;
        }];
    }];
}

// Before the whole page is taken, a notice that has come since the top was looked at (it
// may be put up a good while after the page has loaded, more so when many are loading) is
// looked at too, once: the job is Looked again, to be told what to press. If one is on its way,
// it is waited for a little.
- (void)recheck:(int)waits
{
    if (self.finished) return;
    __weak WSJob *me = self;
    [self.view evaluateJavaScript:kNoticeScript completionHandler:^(id result, NSError *error) {
        WSJob *job = me;
        if (!job || job.finished) return;
        int seen = [result respondsToSelector:@selector(intValue)] ? [result intValue] : 0;
        if (seen == 1 && !job.rechecked && job.lookPath) {
            job.rechecked = YES;
            [job look];
        } else if (seen == 2 && waits < 4 && !job.rechecked) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [me recheck:waits + 1]; });
        } else {
            [job measure];
        }
    }];
}

// Press the button that says label, in the page and its frames, give the page a
// moment to change, and look at it again.
- (void)press:(NSString *)label
{
    if (self.finished) return;
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[label] options:0 error:nil];
    NSString *array = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *script = [NSString stringWithFormat:@"%@(%@[0])", kPressScript, array];
    NSArray<WKFrameInfo *> *frames = [self.frames copy];
    __block NSUInteger pending = 1 + frames.count;
    __block BOOL clicked = NO;
    __weak WSJob *me = self;
    void (^answered)(id, NSError *) = ^(id result, NSError *error) {
        if ([result respondsToSelector:@selector(boolValue)] && [result boolValue]) clicked = YES;
        if (--pending > 0) return;
        WSJob *job = me;
        if (!job || job.finished) return;
        slot_data(job.slot)->pressed = clicked ? 1 : 0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((clicked ? kBannerWait : 0.1) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [me look]; });
    };
    [self.view evaluateJavaScript:script completionHandler:answered];
    for (WKFrameInfo *frame in frames) {
        [self.view evaluateJavaScript:script inFrame:frame inContentWorld:[WKContentWorld pageWorld]
                    completionHandler:answered];
    }
}

// A frame in the page is noted, to look for a banner in it too.
- (void)webView:(WKWebView *)view decidePolicyForNavigationAction:(WKNavigationAction *)action
                                                  decisionHandler:(void (^)(WKNavigationActionPolicy))handler
{
    if (action.targetFrame && !action.targetFrame.isMainFrame && self.frames.count < kMaxFrames)
        [self.frames addObject:action.targetFrame];
    handler(WKNavigationActionPolicyAllow);
}

// Click away what covers the page, in the page and its frames, as many times as
// it comes to (a banner may lead to a second notice); then measure it.
- (void)dismissBanners:(int)round
{
    if (self.finished) return;
    NSArray<WKFrameInfo *> *frames = [self.frames copy];
    __block NSUInteger pending = 1 + frames.count;
    __block BOOL clicked = NO;
    __weak WSJob *me = self;
    void (^answered)(id, NSError *) = ^(id result, NSError *error) {
        if ([result respondsToSelector:@selector(boolValue)] && [result boolValue]) clicked = YES;
        if (--pending > 0) return;
        WSJob *job = me;
        if (!job || job.finished) return;
        if (!clicked) { [job proceed]; return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kBannerWait * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (round < kBannerRounds) [me dismissBanners:round + 1]; else [me proceed];
        });
    };
    [self.view evaluateJavaScript:kDismissScript completionHandler:answered];
    for (WKFrameInfo *frame in frames) {
        [self.view evaluateJavaScript:kDismissScript inFrame:frame inContentWorld:[WKContentWorld pageWorld]
                    completionHandler:answered];
    }
}

// A load that is stopped because it is to be a download is no failure (WebKit error 102).
static BOOL stopped_for_download(WSJob *job, NSError *error)
{
    return job.fetchPath && [error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102;
}

- (void)webView:(WKWebView *)view didFailNavigation:(WKNavigation *)nav withError:(NSError *)error
{
    if (!stopped_for_download(self, error)) [self fail:error.localizedDescription];
}

- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)nav withError:(NSError *)error
{
    if (!stopped_for_download(self, error)) [self fail:error.localizedDescription];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)view
{
    [self fail:@"The page's process stopped"];
}

- (void)measure
{
    if (self.finished) return;
    slot_data(self.slot)->phase = 0.9;
    NSString *script =
        @"Math.max(document.documentElement.scrollHeight,"
         "document.body ? document.body.scrollHeight : 0)";
    __weak WSJob *me = self;
    [self.view evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        WSJob *job = me;
        if (!job || job.finished) return;
        int high = [result respondsToSelector:@selector(intValue)] ? [result intValue] : 0;
        if (high < 1) high = 1;
        [job shoot:high];
    }];
}

// The screens at the top of the page, a window's height each, are written at the full
// scale, as files that can be read by what cannot read a very long page that has been
// made to fit a picture: its words are too small. Then the job is done.
- (void)tile:(int)index of:(int)high picture:(int)picture
{
    int offset = (index - 1) * kLookHeight;
    if (self.finished) return;
    if (!self.tilePrefix || index > kTileCount || offset >= high) {
        self.finished = YES;
        finish(self.slot, WS_DONE, picture, @"");
        return;
    }
    WKSnapshotConfiguration *config = [WKSnapshotConfiguration new];
    config.rect = NSMakeRect(0, offset, self.width, MIN(kLookHeight, high - offset));
    double backing = [NSScreen mainScreen].backingScaleFactor;
    if (backing < 1.0) backing = 1.0;
    config.snapshotWidth = @(self.width * kPixelsPerPoint / backing);
    __weak WSJob *me = self;
    [self.view takeSnapshotWithConfiguration:config completionHandler:^(NSImage *image, NSError *error) {
        WSJob *job = me;
        if (!job || job.finished) return;
        CGImageRef cg = image ? [image CGImageForProposedRect:NULL context:nil hints:nil] : NULL;
        if (!cg) { [job fail:error.localizedDescription ?: @"No snapshot"]; return; }
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *name = [job.tilePrefix stringByAppendingFormat:@"-%d.png", index];
        NSString *temp = [name stringByAppendingString:@".part"];
        if (![png writeToFile:temp atomically:NO] || rename(temp.fileSystemRepresentation, name.fileSystemRepresentation) != 0) {
            [job fail:@"The picture could not be written"];
            return;
        }
        slot_data(job.slot)->tile_count = index;
        [job tile:index + 1 of:high picture:picture];
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
            strlcpy(slot_data(again.slot)->title, again.view.title.UTF8String ?: "", WS_MESSAGE);
            [again tile:1 of:high picture:(int)CGImageGetHeight(cg)];
        }];
    });
}

@end

// Begin to fetch the file the address is of, as the browser would download it (with what it has
// been told by pages loaded before, which a program that is only given the address has not): a
// page that is not a file fails.
int ws_download(int slot, const char *url, const char *path)
{
    if (slot < 0) return 0;
    ensure_slot(slot);
    if (slot_data(slot)->state == WS_WORKING) return 0;
    [NSApplication sharedApplication];
    NSURL *target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    if (!target || !target.scheme) {
        slot_data(slot)->state = WS_FAILED;
        strlcpy(slot_data(slot)->message, "Not a link", WS_MESSAGE);
        return 1;
    }
    WSJob *job = [WSJob new];
    job.slot = slot;
    job.path = [NSString stringWithUTF8String:path];
    job.fetchPath = job.path;
    job.width = 1024;
    job.frames = [NSMutableArray new];
    job.view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 1024, kLookHeight)
                                  configuration:[WKWebViewConfiguration new]];
    job.view.navigationDelegate = job;
    set_job(slot, job);
    slot_data(slot)->state = WS_WORKING;
    slot_data(slot)->title[0] = 0;
    slot_data(slot)->document[0] = 0;
    slot_data(slot)->pressed = 0;
    slot_data(slot)->tile_count = 0;
    slot_data(slot)->phase = 0;
    slot_data(slot)->message[0] = 0;
    if ([target isFileURL]) {
        [job.view loadFileURL:target allowingReadAccessToURL:[target URLByDeletingLastPathComponent]];
    } else {
        [job.view loadRequest:[NSURLRequest requestWithURL:target]];
    }
    __weak WSJob *me = job;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * kLoadTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WSJob *late = me;
        if (late && !late.finished) [late fail:@"Timed out"];
    });
    return 1;
}

int ws_start(int slot, const char *url, const char *path, int width, const char *look, int dismiss,
             const char *tiles)
{
    if (slot < 0) return 0;
    ensure_slot(slot);
    if (slot_data(slot)->state == WS_WORKING) return 0;
    [NSApplication sharedApplication];  // WebKit wants one; SDL's is this
    NSURL *target = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    if (!target || !target.scheme) {
        slot_data(slot)->state = WS_FAILED;
        strlcpy(slot_data(slot)->message, "Not a link", WS_MESSAGE);
        return 1;
    }
    WSJob *job = [WSJob new];
    job.slot = slot;
    job.path = [NSString stringWithUTF8String:path];
    job.width = width;
    job.frames = [NSMutableArray new];
    job.dismiss = dismiss != 0;
    job.lookPath = look && look[0] ? [NSString stringWithUTF8String:look] : nil;
    job.tilePrefix = tiles && tiles[0] ? [NSString stringWithUTF8String:tiles] : nil;
    slot_data(slot)->tile_count = 0;
    slot_data(slot)->document[0] = 0;
    slot_data(slot)->pressed = 0;
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    job.view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, kLookHeight)
                                  configuration:config];
    job.view.navigationDelegate = job;
    set_job(slot, job);
    slot_data(slot)->state = WS_WORKING;
    slot_data(slot)->title[0] = 0;
    slot_data(slot)->phase = 0;
    slot_data(slot)->message[0] = 0;
    if ([target isFileURL]) {
        [job.view loadFileURL:target allowingReadAccessToURL:[target URLByDeletingLastPathComponent]];
    } else {
        [job.view loadRequest:[NSURLRequest requestWithURL:target]];
    }
    __weak WSJob *me = job;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLoadTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WSJob *late = me;
        if (late && !late.finished && !late.loaded) [late fail:@"Timed out"];
    });
    return 1;
}

void ws_pump(int milliseconds)
{
    [[NSRunLoop mainRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow:milliseconds / 1000.0]];
}

// What to do with a job that has been looked at (state WS_LOOKED).
int ws_press(int slot, const char *label)
{
    WSJob *job = job_of(slot);
    if (!job || slot_data(slot)->state != WS_LOOKED) return 0;
    slot_data(slot)->state = WS_WORKING;
    [job press:[NSString stringWithUTF8String:label]];
    return 1;
}

int ws_continue(int slot)
{
    WSJob *job = job_of(slot);
    if (!job || slot_data(slot)->state != WS_LOOKED) return 0;
    slot_data(slot)->state = WS_WORKING;
    if (job.lookPath) [job recheck:0]; else [job measure];
    return 1;
}

int ws_tiles(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->tile_count : 0; }
int ws_pressed(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->pressed : 0; }
const char *ws_document(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->document : ""; }

int ws_state(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->state : WS_IDLE; }
int ws_height(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->height : 0; }
const char *ws_message(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->message : ""; }
// Percent done: the page's load is the first four fifths, then the wait
// for late layout, the measure and the snapshot.
int ws_progress(int slot)
{
    if (slot < 0) return 0;
    if (slot_data(slot)->state == WS_DONE) return 100;
    if (slot_data(slot)->state == WS_LOOKED) return 85;
    if (slot_data(slot)->state != WS_WORKING) return 0;
    double done = slot_data(slot)->phase;
    WSJob *job = job_of(slot);
    if (job && done < 0.8) done = MAX(done, job.view.estimatedProgress * 0.8);
    return (int)(done * 100.0);
}
const char *ws_title(int slot) { return slot >= 0 && slot < slot_count ? slot_data(slot)->title : ""; }
void ws_reset(int slot)
{
    if (slot < 0 || slot >= slot_count) return;
    if (job_of(slot).download) [job_of(slot).download cancel:^(NSData *resume) {}];
    job_of(slot).finished = YES;
    set_job(slot, nil);
    slot_data(slot)->state = WS_IDLE;
    slot_data(slot)->height = 0;
    slot_data(slot)->phase = 0;
    slot_data(slot)->message[0] = 0;
    slot_data(slot)->title[0] = 0;
    slot_data(slot)->document[0] = 0;
    slot_data(slot)->pressed = 0;
    slot_data(slot)->tile_count = 0;
}
