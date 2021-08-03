//
//  AppDelegate.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 3/8/21.
//

#import <Cocoa/Cocoa.h>
#include <zip.h>

@interface AppDelegate: NSObject <NSApplicationDelegate>

@property (nonatomic, retain) NSArray* compressionMethods;
@property (nonatomic) int CompressionMethodIdx;

@property (strong) IBOutlet NSTextField *CompressionMethodText;
@property (strong) IBOutlet NSSlider *CompressionMethodSlider;
@property (strong) IBOutlet NSSecureTextField *EncryptionPasswordField;
@property (strong) IBOutlet NSSecureTextField *EncryptionRepeatField;
@property (strong) IBOutlet NSPopUpButton *EncryptionAlgorithmPopup;

// Functions
- (void)ZipFile:(NSString*)file
		  entry:(NSString*)entry
		 output:(NSString*)output;

// Zip events
void onZipProgress(zip_t *zip, double progress, void *ud);

// Menu events
- (IBAction)FileMenuCreateArchiveClicked:(id)sender;
- (IBAction)FileMenuExtractArchiveClicked:(id)sender;

// Main Window Events
- (IBAction)CompressionMethodSliderChanged:(id)sender;

@end

