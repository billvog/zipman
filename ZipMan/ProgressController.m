//
//  ProgressController.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 4/8/21.
//

#import "ProgressController.h"

@interface ProgressController ()
@end

@implementation ProgressController

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)windowWillClose:(NSNotification *)notification {
	[self DoCancel];
}

- (void)setTaskDescription:(NSString *)TaskDescription {
	[self.TaskDescriptionText setStringValue:TaskDescription];
}

- (void)UpdateProgress:(float) progress {
	// Limit updates to one per 500ms
	NSTimeInterval interval = [NSDate.now timeIntervalSinceDate:self.lastUpdatedProgress];
	if (interval != NAN && interval < 0.5)
		return;
	
	[self.ProgressIndicator setDoubleValue:progress];
	_lastUpdatedProgress = [NSDate now];
}

- (void)DoCancel {
	_isCanceled = TRUE;
	[self.CancelBtn setEnabled:false];
}

- (IBAction)CancelClicked:(id)sender {
	[self DoCancel];
}

@end
