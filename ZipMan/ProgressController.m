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

- (void)SetTaskDescription:(NSString *)TaskDescription {
	[self.TaskDescriptionText setStringValue:TaskDescription];
}

- (void)SetIndeterminate:(BOOL)value {
	[self.ProgressIndicator setIndeterminate:value];
	[self.ProgressIndicator setUsesThreadedAnimation:TRUE];
	[self.ProgressIndicator startAnimation:nil];
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
	[self.delegate onOperationCanceled];
	[self.CancelBtn setEnabled:false];
}

- (IBAction)CancelClicked:(id)sender {
	[self DoCancel];
}

@end
