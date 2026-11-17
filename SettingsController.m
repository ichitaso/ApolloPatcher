#import "header.h"
#import "Image.h"
#import "Backup.h"

@interface SettingsController () <UIDocumentPickerDelegate>
@end

UITextField *editField;

@interface PSTableCell (ApolloPatcher)
@property(readonly, assign, nonatomic) UILabel *textLabel;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(id)specifier;
@end

@interface CustomButtonCell : PSTableCell
@end

@implementation CustomButtonCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        self.detailTextLabel.text = specifier.properties[@"subtitle"] ?: nil;
        //self.detailTextLabel.textColor = [UIColor grayColor];
        if (specifier->cellType == PSLinkCell) {
            self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }

    return self;
}
// iOS 26+: textLabel/detailTextLabel layout drifts
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    if (@available(iOS 14.0, *)) {
        UIListContentConfiguration *config = [UIListContentConfiguration subtitleCellConfiguration];
        config.text = specifier.name;
        config.textProperties.color = [UIColor labelColor];
        config.secondaryText = specifier.properties[@"subtitle"];
        config.secondaryTextProperties.color = [UIColor colorWithWhite:142.f / 255.f alpha:1.f];
        config.image = specifier.properties[@"iconImage"];
        NSDirectionalEdgeInsets margins = config.directionalLayoutMargins;
        margins.top = 10;
        margins.bottom = 10;
        config.directionalLayoutMargins = margins;
        config.textToSecondaryTextVerticalPadding = 2;
        self.contentConfiguration = config;
    }
    if (specifier->cellType == PSLinkCell) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}
@end

@interface redButtonCell : PSTableCell
@end

@implementation redButtonCell
- (void)layoutSubviews {
    [super layoutSubviews];
    // PSButtonCell
    self.textLabel.textColor = [UIColor redColor];
}
@end

@implementation SettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ApolloPatcher";

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonTapped:)];
    self.navigationItem.rightBarButtonItem = doneButton;
}

- (void)doneButtonTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage *)decodeAndResizeBase64Image:(NSString *)base64String {
    NSURL *imageUrl = [NSURL URLWithString:base64String];
    NSData *imageData = [NSData dataWithContentsOfURL:imageUrl options:NSDataReadingUncached error:nil];
    UIImage *image = [UIImage imageWithData:imageData];

    const CGFloat imageSize = 40;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(imageSize, imageSize)];
    UIImage *resizedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, imageSize, imageSize) cornerRadius:20.0] addClip];
        [image drawInRect:CGRectMake(0, 0, imageSize, imageSize)];
    }];

    return resizedImage;
}

- (id)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;

        spec = [PSSpecifier preferenceSpecifierNamed:@"How to Use"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSGroupCell
                                                edit:nil];
        [spec setProperty:@"You will need to set up \"Apollo for Reddit\" to use it as your personal app." forKey:@"footerText"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Description"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSLinkCell
                                                edit:nil];
        spec->action = @selector(howtoUse);
        [spec setProperty:[self decodeAndResizeBase64Image:b64Willfeeltips] forKey:@"iconImage"];
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [spec setProperty:@"ApolloPatcher | ichitaso's Repository" forKey:@"subtitle"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Custom API"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSGroupCell
                                                edit:nil];
        [spec setProperty:@"Get the Client IDs of Reddit and Imgur and enter them separately. Turn on Use Dystopia when the Reddit API Key is Dystopia's App ID." forKey:@"footerText"];
        [specifiers addObject:spec];

        PSTextFieldSpecifier *textspec;

        textspec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Reddit API Key"
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSEditTextCell
                                                             edit:nil];
        [textspec setProperty:@"Custom_ID" forKey:@"key"];
        [textspec setPlaceholder:@"Reddit API Key"];
        [specifiers addObject:textspec];

        textspec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Imgur API Key"
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSEditTextCell
                                                             edit:nil];
        [textspec setProperty:@"IMGUR_ID" forKey:@"key"];
        [textspec setPlaceholder:@"Imgur API Key"];
        [specifiers addObject:textspec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Use Dystopia"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:nil
                                                cell:PSSwitchCell
                                                edit:nil];
        [spec setProperty:@"Use_Dystopia" forKey:@"key"];
        [spec setProperty:@NO forKey:@"default"];
        [specifiers addObject:spec];

        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"After setting, tap Apply and close the application to activate it." forKey:@"footerText"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Apply"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];

        spec->action = @selector(tapClose);
        [spec setProperty:@2 forKey:@"alignment"];
        [specifiers addObject:spec];

        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"Reset settings and close the application." forKey:@"footerText"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];

        spec->action = @selector(tapReset);
        [spec setProperty:@2 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"redButtonCell") forKey:@"cellClass"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Backup"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSGroupCell
                                                edit:nil];
        [spec setProperty:@"Back up your documents, settings and keychain (accounts). The backup file contains your login tokens unencrypted, so keep it safe." forKey:@"footerText"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Backup"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];
        spec->action = @selector(tapBackup);
        [spec setProperty:@2 forKey:@"alignment"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Restore"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];
        spec->action = @selector(tapRestore);
        [spec setProperty:@2 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"redButtonCell") forKey:@"cellClass"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Credits"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSGroupCell
                                                edit:nil];
        [spec setProperty:@"© Will feel Tips by ichitaso" forKey:@"footerText"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"X (Twitter)"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];

        spec->action = @selector(openTwitter);
        [spec setProperty:[self decodeAndResizeBase64Image:b64ichitaso] forKey:@"iconImage"];
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [spec setProperty:@"@ichitaso" forKey:@"subtitle"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Source Code"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSLinkCell
                                                edit:nil];
        spec->action = @selector(openGitHub);
        [spec setProperty:[self decodeAndResizeBase64Image:b64GitHub] forKey:@"iconImage"];
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [spec setProperty:@"Open source on GitHub" forKey:@"subtitle"];
        [specifiers addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Donate"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSLinkCell
                                                edit:nil];
        spec->action = @selector(donate);
        [spec setProperty:[self decodeAndResizeBase64Image:b64Paypal] forKey:@"iconImage"];
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [spec setProperty:@"If you like my work, Please a donation." forKey:@"subtitle"];
        [specifiers addObject:spec];

        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:[specifier identifier]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self reloadSpecifiers];
    }
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    @autoreleasepool {
        return [[NSUserDefaults standardUserDefaults] objectForKey:[specifier identifier]] ?:[[specifier properties] objectForKey:@"default"];
    }
}

- (void)_returnKeyPressed:(id)arg1 {
    [super _returnKeyPressed:arg1];
    [self.view endEditing:YES];
}

- (void)tapClose {
    [[UIApplication sharedApplication] closeAppAnimatedExit];
}

- (void)tapReset {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Custom_ID"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"IMGUR_ID"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Use_Dystopia"];
    [[UIApplication sharedApplication] closeAppAnimatedExit];
}

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Runs work off the main thread while a progress alert is shown
- (void)runWithProgress:(NSString *)title work:(id (^)(NSString **error))work completion:(void (^)(id result, NSString *error))completion {
    UIAlertController *progress = [UIAlertController alertControllerWithTitle:title
                                                                      message:nil
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progress animated:YES completion:^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *error = nil;
            id result = work(&error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [progress dismissViewControllerAnimated:YES completion:^{
                    completion(result, error);
                }];
            });
        });
    }];
}

- (void)tapBackup {
    [self runWithProgress:@"Backing up..." work:^id(NSString **error) {
        return APCreateBackup(error);
    } completion:^(NSURL *url, NSString *error) {
        if (!url) {
            [self showMessage:@"Backup Failed" message:error];
            return;
        }
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        activity.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        };
        if (IS_PAD) {
            CGRect rect = self.view.bounds;
            activity.popoverPresentationController.sourceView = self.view;
            activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect), CGRectGetMidY(rect), 1, 1);
            activity.popoverPresentationController.permittedArrowDirections = 0;
        }
        [self presentViewController:activity animated:YES completion:nil];
    }];
}

- (void)tapRestore {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.tar-archive", @"public.data"]
                                                                                                    inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    [self runWithProgress:@"Loading..." work:^id(NSString **error) {
        NSDictionary *manifest = APPrepareRestore(url, error);
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        return manifest;
    } completion:^(NSDictionary *manifest, NSString *error) {
        if (!manifest) {
            [self showMessage:@"Cannot Restore" message:error];
            return;
        }
        NSString *date = @"";
        if ([manifest[@"date"] isKindOfClass:[NSDate class]]) {
            date = [NSDateFormatter localizedStringFromDate:manifest[@"date"] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
        }
        NSString *message = [NSString stringWithFormat:@"%@ (Apollo %@)\n\nAll current data will be overwritten. The app will close and restore on the next launch.", date, manifest[@"appVersion"] ?: @""];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restore?"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            if (!APCommitRestore()) {
                APCancelRestore();
                [self showMessage:@"Cannot Restore" message:@"Failed to write a temporary file."];
                return;
            }
            [[UIApplication sharedApplication] closeAppAnimatedExit];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            APCancelRestore();
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)openTwitter {
    NSString *twitterID = @"ichitaso";

    alertController = [UIAlertController
                       alertControllerWithTitle:[NSString stringWithFormat:@"Follow @%@",twitterID]
                       message:nil
                       preferredStyle:UIAlertControllerStyleActionSheet];

    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Twitter" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"twitter://user?screen_name=%@",twitterID]]
                                               options:@{}
                                     completionHandler:nil];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Browser" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:[NSString stringWithFormat:@"https://twitter.com/%@",twitterID]];
        });
    }]];
    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    }

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)howtoUse {
    NSString *urlStr = @"https://cydia.ichitaso.com/depiction/apollopatcher.html";

    alertController = [UIAlertController
                       alertControllerWithTitle:nil
                       message:nil
                       preferredStyle:UIAlertControllerStyleActionSheet];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]
                                           options:@{}
                                 completionHandler:nil];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Browser" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:urlStr];
        });
    }]];
    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    }

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)openGitHub {
    [self openURLInBrowser:@"https://github.com/ichitaso/ApolloPatcher"];
}

- (void)donate {
    [self openURLInBrowser:@"https://cydia.ichitaso.com/donation.html"];
}

- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url]];
    [self presentViewController:safari animated:YES completion:nil];
}
// PSEDitCell Add Clear Button
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

    if ([cell isKindOfClass:objc_getClass("PSEditableTableCell")]) {
        PSEditableTableCell *editableCell = (PSEditableTableCell *)cell;
        if (editableCell.textField) {
            editField = editableCell.textField;
            editField.clearButtonMode = UITextFieldViewModeWhileEditing;
        }
    }
    
    return cell;
}

@end
