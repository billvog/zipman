//
//  AppDelegate.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 3/8/21.
//

#import <Cocoa/Cocoa.h>
#include <zip.h>

#import "ProgressController.h"

@interface AppDelegate: NSObject <NSApplicationDelegate>

// Variables
@property (nonatomic, retain) NSArray* compressionMethods;
@property (nonatomic) int CompressionMethodIdx;

@property (nonatomic, retain) NSArray* encryptionAlgorithms;
@property (nonatomic) int EncryptionAlgorithmIdx;

// UI Elements
@property (strong) IBOutlet NSTextField *CompressionMethodText;
@property (strong) IBOutlet NSSlider *CompressionMethodSlider;
@property (strong) IBOutlet NSSecureTextField *EncryptionPasswordField;
@property (strong) IBOutlet NSSecureTextField *EncryptionRepeatField;
@property (strong) IBOutlet NSPopUpButton *EncryptionAlgorithmPopup;

@property ProgressController *progressController;

// Functions
- (void)ZipFile:(NSString*)file
		zipFile:(zip_t*)zip
	  entryName:(NSString*)entry
	   password:(NSString*)password;

- (void)ZipAddDir:(zip_t*)zip
		entryName:(NSString*)entry;

- (void)WalkDirToZip:(NSString*)path
			 zipFile:(zip_t*)zip
	   baseEntryName:(NSString*)baseEntry
			password:(NSString*)password;

// Zip events
void onZipProgress(zip_t *zip, double progress, void *ud);

// Menu events
- (IBAction)FileMenuCreateArchiveClicked:(id)sender;
- (IBAction)FileMenuExtractArchiveClicked:(id)sender;

// Main Window Events
- (IBAction)CompressionMethodSliderChanged:(id)sender;
- (IBAction)PasswordFieldChanged:(id)sender;
- (IBAction)RepeatPasswordFieldChanged:(id)sender;
- (IBAction)EncryptionAlgorithmChanged:(id)sender;

@end

