//
//  PasswordPromptController.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 5/8/21.
//

#import "PasswordPromptController.h"

@interface PasswordPromptController ()
@end

@implementation PasswordPromptController

- (void)windowDidLoad {
    [super windowDidLoad];
	[self.DecryptButton setKeyEquivalent:@"\r"];
}

- (NSString*)GetPassword {
	return [self.PasswordField stringValue];
}

- (IBAction)DecryptClicked:(id)sender {
	[NSApp stopModalWithCode:NSModalResponseOK];
	[NSApp endSheet:self.window];
}

- (IBAction)CancelClicked:(id)sender {
	[NSApp stopModalWithCode:NSModalResponseCancel];
	[NSApp endSheet:self.window];
}

@end
