//
//  AppDelegate.h
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 3/8/21.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

#import "ProgressController.h"
#import "PasswordPromptController.h"

// Archive Handlers
#import "ZipHandler.h"

// Preferences keys
#define ArchiveFormatPrefKey		@"ArchiveFormat"
#define ExcludeMacResForksPrefKey 	@"ExcludeMacResForks"
#define DelFilesAfterCompPrefKey 	@"DeleteFilesAfterCompression"

@interface AppDelegate: NSObject <NSApplicationDelegate, NSTextFieldDelegate, ProgressDelegate, BaseArchiveHandlerDelegate>

// Variables
@property (nonatomic) BaseArchiveHandler* archiveHandler;

@property (nonatomic, retain) NSArray* 	archiveFormats;
@property (nonatomic, retain) NSArray* 	archiveFormatExtensions;
@property (nonatomic) int 				ArchiveFormatIdx;

@property (nonatomic, retain) NSArray* 	compressionMethods;
@property (nonatomic) int 				CompressionMethodIdx;

@property (nonatomic, retain) NSArray* 	encryptionAlgorithms;
@property (nonatomic) int 				EncryptionAlgorithmIdx;
@property (nonatomic) BOOL 				isEncryptionEnabled;

@property AVAudioPlayer* audioPlayer;

// UI Elements
@property (strong) IBOutlet NSPopUpButton*		ArchiveFormatSelector;
@property (strong) IBOutlet NSTextField*		CompressionMethodText;
@property (strong) IBOutlet NSSlider*			CompressionMethodSlider;
@property (strong) IBOutlet NSSecureTextField*	EncryptionPasswordField;
@property (strong) IBOutlet NSSecureTextField*	EncryptionRepeatField;
@property (strong) IBOutlet NSPopUpButton*		EncryptionAlgorithmPopup;
@property (strong) IBOutlet NSImageView*		EncryptionPasswordValidLock;
@property (strong) IBOutlet NSImageView*		EncryptionRepeatValid;
@property (strong) IBOutlet NSButton*			ExcludeMacResForksCheckbox;
@property (strong) IBOutlet NSButton* 			DelAfterCompCheckbox;

@property ProgressController *progressController;

// Functions
- (void)LoadPrefs;
- (void)OpenProgressWindow:(NSString*)title
		   taskDescription:(NSString*)task;

- (void)CheckEncryptionEnabled;

- (void)WalkDirToArchive:(NSString*)path
		   baseEntryName:(NSString*)baseEntry;

- (void)CreateArchive:(NSURL*)inputURL;
- (void)ExtractArchive:(NSURL*)archiveURL;

// Setup Archive Handlers
- (void)SetupSelectedArchiveHandler;
- (void)SetupZipHandler;

// Menu events
- (IBAction)FileMenuCreateArchiveClicked:(id)sender;
- (IBAction)FileMenuExtractArchiveClicked:(id)sender;

// Toolbar events
- (IBAction)ArchiveFormatChanged:(id)sender;
- (void)ArchiveFormatHandleChange;

// Main Window Events
- (IBAction)CompressionMethodSliderChanged:(id)sender;
- (IBAction)EncryptionAlgorithmChanged:(id)sender;
- (IBAction)ExcludeMacResForksCheckboxChanged:(id)sender;
- (IBAction)DelAfterCompCheckboxChanged:(id)sender;

@end

