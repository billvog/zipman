//
//  AppDelegate.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 3/8/21.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#include <zip.h>

#import "ProgressController.h"
#import "PasswordPromptController.h"

// Preferences keys
#define ExcludeMacResForksPrefKey 	@"ExcludeMacResForks"
#define DelFilesAfterCompPrefKey 	@"DeleteFilesAfterCompression"

@interface AppDelegate: NSObject <NSApplicationDelegate, NSTextFieldDelegate>

// Variables
@property (nonatomic, retain) NSArray* compressionMethods;
@property (nonatomic) int CompressionMethodIdx;

@property (nonatomic, retain) NSArray* encryptionAlgorithms;
@property (nonatomic) int EncryptionAlgorithmIdx;
@property (nonatomic) BOOL isEncryptionEnabled;

@property AVAudioPlayer* audioPlayer;

// UI Elements
@property (strong) IBOutlet NSTextField *CompressionMethodText;
@property (strong) IBOutlet NSSlider *CompressionMethodSlider;
@property (strong) IBOutlet NSSecureTextField *EncryptionPasswordField;
@property (strong) IBOutlet NSSecureTextField *EncryptionRepeatField;
@property (strong) IBOutlet NSPopUpButton *EncryptionAlgorithmPopup;
@property (strong) IBOutlet NSImageView *EncryptionPasswordValidLock;
@property (strong) IBOutlet NSImageView *EncryptionRepeatValid;
@property (strong) IBOutlet NSButton *ExcludeMacResForksCheckbox;
@property (strong) IBOutlet NSButton *DelAfterCompCheckbox;

@property ProgressController *progressController;

// Functions
- (void)LoadPrefs;

- (void)CheckEncryptionEnabled;

- (void)ZipFile:(NSString*)file
		zipFile:(zip_t*)zip
	  entryName:(NSString*)entry;

- (void)ZipAddDir:(zip_t*)zip
		entryName:(NSString*)entry;

- (void)WalkDirToZip:(NSString*)path
			 zipFile:(zip_t*)zip
	   baseEntryName:(NSString*)baseEntry;

// Zip events
void onZipCloseProgress(zip_t *zip, double progress, void *ud);
int onZipCloseCancel(zip_t *zip, void *ud);

// Menu events
- (IBAction)FileMenuCreateArchiveClicked:(id)sender;
- (IBAction)FileMenuExtractArchiveClicked:(id)sender;

// Main Window Events
- (IBAction)CompressionMethodSliderChanged:(id)sender;
- (IBAction)EncryptionAlgorithmChanged:(id)sender;
- (IBAction)ExcludeMacResForksCheckboxChanged:(id)sender;
- (IBAction)DelAfterCompCheckboxChanged:(id)sender;

@end

