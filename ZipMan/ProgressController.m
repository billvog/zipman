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

- (void)UpdateProgress:(float) progress {
	// Limit updates to one per 500ms
	NSTimeInterval interval = [NSDate.now timeIntervalSinceDate:_lastUpdatedProgress];
	if (interval != NAN && interval < 0.5)
		return;
	
	[_ProgressIndicator setDoubleValue:progress];
	[_ProgressText setStringValue:[NSString stringWithFormat:@"%.1f%%", progress]];
	
	_lastUpdatedProgress = [NSDate now];
	
//	NSLog(@"Zip progress: %.1f", progress);
}

- (IBAction)CancelClicked:(id)sender {
	_isCanceled = TRUE;
	[_CancelBtn setEnabled:false];
}

@end
