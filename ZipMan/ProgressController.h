//
//  ProgressController.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 4/8/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProgressController: NSWindowController

@property (strong) IBOutlet NSProgressIndicator *ProgressIndicator;
@property (strong) IBOutlet NSTextField *ProgressText;

- (void) UpdateProgress:(float) progress;

@end

NS_ASSUME_NONNULL_END
