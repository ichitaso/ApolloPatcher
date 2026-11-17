#import "WebAuth.h"
#import <WebKit/WebKit.h>

// Only used on iOS 13-15 (see LegacyWebAuth in Tweak.xm)
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

// Features Reddit's login pages use that older WebKit lacks
static NSString *const kPolyfill =
    @"if (!HTMLFormElement.prototype.requestSubmit) {"
     "  HTMLFormElement.prototype.requestSubmit = function () {"
     "    var e = document.createEvent('Event');"
     "    e.initEvent('submit', true, true);"
     "    if (this.dispatchEvent(e)) this.submit();"
     "  };"
     "}"
     "[Array, String].forEach(function (C) {"
     "  if (!C.prototype.at) Object.defineProperty(C.prototype, 'at', { configurable: true, writable: true, value: function (i) {"
     "    i = Math.trunc(i) || 0; if (i < 0) i += this.length; return i < 0 || i >= this.length ? undefined : this[i];"
     "  } });"
     "});"
     "if (!Object.hasOwn) Object.hasOwn = function (o, k) { return Object.prototype.hasOwnProperty.call(o, k); };"
     "if (!window.structuredClone) window.structuredClone = function (v) { return v === undefined ? v : JSON.parse(JSON.stringify(v)); };"
     "if (window.crypto && !crypto.randomUUID) crypto.randomUUID = function () {"
     "  var b = crypto.getRandomValues(new Uint8Array(16)); b[6] = b[6] & 15 | 64; b[8] = b[8] & 63 | 128;"
     "  var h = [].map.call(b, function (x) { return (x + 256).toString(16).slice(1); }).join('');"
     "  return h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20);"
     "};"
     // The Allow form posts to www.reddit.com/api/v1/authorize, which only accepts GET now
     "document.addEventListener('DOMContentLoaded', function () {"
     "  [].forEach.call(document.querySelectorAll('form[action=\"/api/v1/authorize\"]'), function (f) { f.setAttribute('action', 'https://old.reddit.com/api/v1/authorize'); });"
     "});";

BOOL APIsRedditAuthorizeURL(NSURL *url) {
    return [url.host hasSuffix:@"reddit.com"] && [url.path hasPrefix:@"/api/v1/authorize"];
}

static BOOL cookieMatchesURL(NSHTTPCookie *cookie, NSURL *url) {
    NSString *host = url.host.lowercaseString;
    NSString *domain = cookie.domain.lowercaseString;
    if ([domain hasPrefix:@"."]) domain = [domain substringFromIndex:1];
    BOOL domainOK = [host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]];
    NSString *path = url.path.length ? url.path : @"/";
    return domainOK && [path hasPrefix:cookie.path ?: @"/"] && (!cookie.isSecure || [url.scheme isEqualToString:@"https"]);
}

@interface APWebAuthViewController () <WKNavigationDelegate, WKUIDelegate, NSURLSessionTaskDelegate>
@end

@implementation APWebAuthViewController {
    NSURL *_url;
    NSString *_scheme;
    void (^_completion)(NSURL *);
    WKWebView *_webView;
    NSURLSession *_session;
    NSURL *_proxiedURL;
}

- (instancetype)initWithURL:(NSURL *)url callbackScheme:(NSString *)scheme completion:(void (^)(NSURL *))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _url = url;
        _scheme = [scheme copy];
        _completion = [completion copy];
        if (@available(iOS 13.0, *)) {
            self.modalInPresentation = YES;
        }
    }
    return self;
}

- (void)loadView {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:kPolyfill injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [config.userContentController addUserScript:script];

    _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    // Same User-Agent for the WebView and the proxied document requests
    NSOperatingSystemVersion os = [NSProcessInfo processInfo].operatingSystemVersion;
    NSString *version = [NSString stringWithFormat:@"%ld_%ld", (long)os.majorVersion, (long)os.minorVersion];
    _webView.customUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/%ld.%ld Mobile/15E148 Safari/604.1",
                                version, (long)os.majorVersion, (long)os.minorVersion];
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    self.view = _webView;

    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sessionConfig.HTTPShouldSetCookies = NO;
    sessionConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Reddit";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    [self loadProxied:_url];
}

- (void)cancel {
    [self finishWithURL:nil];
}

- (void)finishWithURL:(NSURL *)url {
    void (^completion)(NSURL *) = _completion;
    _completion = nil;
    if (!completion) return;
    [_session invalidateAndCancel];
    [self dismissViewControllerAnimated:YES completion:^{
        completion(url);
    }];
}

#pragma mark - CSP stripping

// iOS < 15.4 ignores CSP 'strict-dynamic', which blocks every script Reddit loads at runtime.
// Fetch the document ourselves and hand it to the WebView without the CSP header.
- (void)loadProxied:(NSURL *)url {
    WKHTTPCookieStore *store = _webView.configuration.websiteDataStore.httpCookieStore;
    [store getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        NSMutableArray *matching = [NSMutableArray array];
        for (NSHTTPCookie *cookie in cookies) {
            if (cookieMatchesURL(cookie, url)) [matching addObject:cookie];
        }
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPShouldHandleCookies = NO;
        [request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:matching]];
        [request setValue:self->_webView.customUserAgent forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
        [[self->_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self didLoadProxied:url data:data response:(NSHTTPURLResponse *)response error:error];
        }] resume];
    }];
}

- (void)didLoadProxied:(NSURL *)url data:(NSData *)data response:(NSHTTPURLResponse *)response error:(NSError *)error {
    if (!_completion) return;
    if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
        [_webView loadRequest:[NSURLRequest requestWithURL:url]];
        return;
    }

    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:url];
    WKHTTPCookieStore *store = _webView.configuration.websiteDataStore.httpCookieStore;
    dispatch_group_t group = dispatch_group_create();
    for (NSHTTPCookie *cookie in cookies) {
        dispatch_group_enter(group);
        [store setCookie:cookie completionHandler:^{
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSInteger status = response.statusCode;
        NSString *location = response.allHeaderFields[@"Location"];
        if (status >= 300 && status < 400 && location.length) {
            NSURL *next = [NSURL URLWithString:location relativeToURL:url].absoluteURL;
            if ([next.scheme caseInsensitiveCompare:self->_scheme] == NSOrderedSame) {
                [self finishWithURL:next];
            } else if ([self shouldProxy:next]) {
                [self loadProxied:next];
            } else {
                [self->_webView loadRequest:[NSURLRequest requestWithURL:next]];
            }
            return;
        }
        self->_proxiedURL = url;
        [self->_webView loadData:data ?: [NSData data]
                        MIMEType:response.MIMEType ?: @"text/html"
           characterEncodingName:response.textEncodingName ?: @"utf-8"
                         baseURL:url];
    });
}

- (BOOL)shouldProxy:(NSURL *)url {
    return [url.scheme isEqualToString:@"https"] && [url.host hasSuffix:@"reddit.com"];
}

// Redirects are followed by loadProxied so their cookies reach the WebView
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

#pragma mark - WKWebView

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if ([url.scheme caseInsensitiveCompare:_scheme] == NSOrderedSame) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self finishWithURL:url];
        return;
    }
    if (_proxiedURL && [url isEqual:_proxiedURL]) {
        _proxiedURL = nil;
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    // POSTs (the Allow button) keep their body by going through the WebView
    if (navigationAction.targetFrame.isMainFrame && [navigationAction.request.HTTPMethod isEqualToString:@"GET"] && [self shouldProxy:url]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self loadProxied:url];
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

// target="_blank" links
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    [webView loadRequest:navigationAction.request];
    return nil;
}

@end
