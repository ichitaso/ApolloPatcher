#import <UIKit/UIKit.h>

// Reddit sign-in in a WKWebView, for iOS versions whose Safari can't run Reddit's login pages.
// The completion gets the callback URL, or nil when cancelled.
@interface APWebAuthViewController : UIViewController
- (instancetype)initWithURL:(NSURL *)url callbackScheme:(NSString *)scheme completion:(void (^)(NSURL *callbackURL))completion;
@end

__BEGIN_DECLS
BOOL APIsRedditAuthorizeURL(NSURL *url);
__END_DECLS
