//
//  ProgressController.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 4/8/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProgressController: NSWindowController

@property (readonly) BOOL isCanceled;

@property (strong) IBOutlet NSProgressIndicator *ProgressIndicator;
@property (strong) IBOutlet NSTextField *ProgressText;
@property (strong) IBOutlet NSButton *CancelBtn;

- (void)UpdateProgress:(float) progress;

- (IBAction)CancelClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
