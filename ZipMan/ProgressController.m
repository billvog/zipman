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

- (void) UpdateProgress:(float) progress {
	[_ProgressIndicator setDoubleValue:progress];
	[_ProgressText setStringValue:[NSString stringWithFormat:@"%d%%", (int) progress]];
	
//	NSLog(@"Zip Progress: %.1f", progress);
}

@end
