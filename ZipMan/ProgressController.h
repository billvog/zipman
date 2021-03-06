//
//  ProgressController.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 4/8/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ProgressDelegate <NSObject>
- (void)onOperationCanceled;
@end

@interface ProgressController: NSWindowController<NSWindowDelegate>
@property (nonatomic, weak) id <ProgressDelegate> delegate;

@property (readonly) NSDate *lastUpdatedProgress;
@property (readonly) BOOL isCanceled;

@property (strong) IBOutlet NSTextField *TaskDescriptionText;
@property (strong) IBOutlet NSProgressIndicator *ProgressIndicator;
@property (strong) IBOutlet NSButton *CancelBtn;

- (void)SetTaskDescription:(NSString *)TaskDescription;
- (void)SetIndeterminate:(BOOL)value;
- (void)UpdateProgress:(float)progress;
- (void)DoCancel;

- (IBAction)CancelClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
