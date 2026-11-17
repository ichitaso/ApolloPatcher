#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import "Preferences.h"

#define NSLog(fmt, ...) NSLog((@"ApolloPatcher:" fmt), ##__VA_ARGS__)

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
#define COLOR_BACKGROUND [UIColor colorWithRed:0.12 green:0.16 blue:0.61 alpha:1.0]
#define RANDSTRING  [[NSProcessInfo processInfo] globallyUniqueString]
#define RANDINT (arc4random() % 9) + 1

static NSString *kCustomID;
static NSString *kRedirectURI;
static NSString *kUserAgent;
static NSString *kClientID;

@interface ShareUrlTask : NSObject
@property (nonatomic) dispatch_group_t dispatchGroup;
@property (nonatomic, strong) NSString *resolvedURL;
@end

@interface RDKLink
@property(copy, nonatomic) NSURL *URL;
@end

@class _TtC6Apollo14LinkButtonNode;

static UIAlertController *alertController;

@protocol SFSafariViewControllerDelegate;
@import SafariServices;

@interface SettingsController : PSListController <SFSafariViewControllerDelegate>
@property (nonatomic, strong) id <SFSafariViewControllerDelegate> delegate;
@end

@interface UIApplication (Private)
- (void)suspend;
- (void)terminateWithSuccess;
@end

@interface UIApplication (AnimatedExitToSpringBoard)
- (void)closeAppAnimatedExit;
@end

@implementation UIApplication (AnimatedExitToSpringBoard)
- (void)closeAppAnimatedExit {
    BOOL multitaskingSupported = NO;
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
        multitaskingSupported = [UIDevice currentDevice].multitaskingSupported;
    }
    if ([self respondsToSelector:@selector(suspend)]) {
        if (multitaskingSupported) {
            [self beginBackgroundTaskWithExpirationHandler:^{}];
            [self performSelector:@selector(exit) withObject:nil afterDelay:0.4];
        }
        [self suspend];
    } else {
        [self exit];
    }
}

- (void)exit {
    if ([self respondsToSelector:@selector(terminateWithSuccess)]) {
        [self terminateWithSuccess];
    } else {
        exit(0);
    }
}
@end
