//
//  PasswordPromptController.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 5/8/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PasswordPromptController : NSWindowController

@property (strong) IBOutlet NSSecureTextField *PasswordField;
@property (strong) IBOutlet NSButton *DecryptButton;

- (NSString*)GetPassword;

- (IBAction)DecryptClicked:(id)sender;
- (IBAction)CancelClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
