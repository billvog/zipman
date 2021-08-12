//
//  AppDelegate.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 3/8/21.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Compression settings
	self.CompressionMethodIdx = 4;
	self.compressionMethods = [[NSArray alloc] initWithObjects:
							   @"Store, without compression", @"Very fast, less compression",
							   @"Fast, less compression", @"Normal", @"Slow, a lot of compression",
							   @"Very slow, the best compression", nil];
	
	// Encryption settings
	self.EncryptionAlgorithmIdx = 0;
	self.encryptionAlgorithms = [[NSArray alloc] initWithObjects:
								 @"AES-128", @"AES-192", @"AES-256", nil];
	
	[self.EncryptionAlgorithmPopup removeAllItems];
	[self.EncryptionAlgorithmPopup addItemsWithTitles:self.encryptionAlgorithms];
	
	self.EncryptionPasswordField.delegate = self;
	self.EncryptionRepeatField.delegate = self;
	
	// Setup toolbar
	self.archiveFormats = [[NSArray alloc] initWithObjects:@"ZIP", @"TAR", nil];
	self.archiveFormatExtensions = [[NSArray alloc] initWithObjects:@"zip", @"tar", nil];
	
	[self.ArchiveFormatSelector removeAllItems];
	[self.ArchiveFormatSelector addItemsWithTitles:self.archiveFormats];
	
	// Load preferences
	[self LoadPrefs];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return TRUE;
}

- (void)LoadPrefs {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	_ArchiveFormatIdx = (int) [userDefaults integerForKey:ArchiveFormatPrefKey];
	BOOL ExcludeMacResForks = [userDefaults boolForKey:ExcludeMacResForksPrefKey];
	BOOL DelFilesAfterComp = [userDefaults boolForKey:DelFilesAfterCompPrefKey];
	
	// Apply them to the UI
	[self ArchiveFormatHandleChange];
	[self.ExcludeMacResForksCheckbox setState:ExcludeMacResForks ? NSControlStateValueOn : NSControlStateValueOff];
	[self.DelAfterCompCheckbox setState:DelFilesAfterComp ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)OpenProgressWindow:(NSString*)title taskDescription:(NSString*)task {
	self.progressController = [[ProgressController alloc] initWithWindowNibName:@"ProgressWindow"];
	self.progressController.delegate = self;
	[self.progressController showWindow:self];
	[[self.progressController window] setTitle:title];
	[self.progressController SetTaskDescription:task];
	[self.progressController SetIndeterminate:self.archiveHandler.SupportsProgress];
}

- (void)onOperationCanceled {
	if (self.archiveHandler != nil)
		[self.archiveHandler CancelOperation];
}

- (void)RmFileOrThrow:(NSString*)file {
	NSError *error;
	bool ok = [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
	if (!ok) {
		[NSException raise:@"Error removing file" format:@"Error removing file at %@: %@", file, error.localizedDescription];
	}
}

- (void)WalkDirToArchive:(NSString*)path
		   baseEntryName:(NSString*)baseEntry
{
	NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
	[dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *filename = (NSString *)obj;
		
		if ([self.ExcludeMacResForksCheckbox state] == NSControlStateValueOn &&
			[filename isEqualToString:@".DS_Store"]) {
			NSLog(@"Skipping %@ because WithoutMacResForksCheckbox is checked", filename);
			return;
		}
		
		NSString *entryName = [NSString stringWithFormat:@"%@/%@", baseEntry, filename];
		NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, filename];
		NSURL *fileUrl = [NSURL fileURLWithPath:fullPath];
		
		dispatch_sync(dispatch_get_main_queue(), ^{
			// Update task on progress window
			[self onArchiveTaskChanged:[NSString stringWithFormat:@"Adding \"%@\"", fullPath]];
		});
		
		if ([fileUrl hasDirectoryPath]) {
			[self.archiveHandler AddDir:fullPath entryName:entryName];
			[self WalkDirToArchive:fullPath baseEntryName:entryName];
		}
		else {
			[self.archiveHandler AddFile:fullPath entryName:entryName];
		}
	}];
}

// Archive events
- (void)onArchiveProgress:(double)progress {
	[self.progressController UpdateProgress:progress];
}

- (NSString*)onArchiveAskPwdForEncryption {
	PasswordPromptController *pwdPromptCtrl = [[PasswordPromptController alloc]
											   initWithWindowNibName:@"PasswordPrompt"];

	// Show PasswordPrompt as sheet
	[self.window beginSheet:pwdPromptCtrl.window completionHandler:nil];
	NSModalResponse returnCode = [NSApp runModalForWindow:pwdPromptCtrl.window];

	// Check response
	if (returnCode != NSModalResponseOK) {
		return nil;
	}
	
	[NSApp endSheet:pwdPromptCtrl.window];
	[pwdPromptCtrl.window orderOut:self];
	
	return [pwdPromptCtrl GetPassword];
}

- (void)onArchiveWrongPwd {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:@"Incorrect password"];
	[alert setInformativeText:@"The provided password does not match the password used for encryption."];
	[alert runModal];
}

- (void)onArchiveTaskChanged:(nonnull NSString *)task {
	if (self.progressController != nil) {
		[self.progressController SetTaskDescription:task];
	}
}

- (void)SetupSelectedArchiveHandler {
	switch (self.ArchiveFormatIdx) {
		case ZIP_IDX:
			[self SetupZipHandler];
			break;
		case TAR_IDX:
			[self SetupTarHandler];
			break;
		default:
			[NSException raise:@"Unsupported archive format" format:@"The selected archive format is not supported"];
	}
}

- (void)SetupZipHandler {
	// Load handler
	self.archiveHandler = [[ZipHandler alloc] init];
	self.archiveHandler.delegate = self;
	
	// Encryption Method
	uint16_t EncryptionMethod;
	switch (_EncryptionAlgorithmIdx) {
		case 0:
			EncryptionMethod = ZIP_EM_AES_128;
			break;
		case 1:
			EncryptionMethod = ZIP_EM_AES_192;
			break;
		case 2:
			EncryptionMethod = ZIP_EM_AES_256;
			break;
		default:
			EncryptionMethod = ZIP_EM_AES_128;
			break;
	}
	
	// Compression Level
	int32_t CompressionLevel;
	switch (_CompressionMethodIdx) {
		case 1:
			CompressionLevel = 1;
			break;
		case 2:
			CompressionLevel = 3;
			break;
		case 3:
			CompressionLevel = 5;
			break;
		case 4:
			CompressionLevel = 7;
			break;
		case 5:
			CompressionLevel = 9;
			break;
		default:
			CompressionLevel = 0;
			break;
	}
	
	// Configure
	[self.archiveHandler SetCompressionLevel:CompressionLevel];
	[self.archiveHandler SetEncryptionAlgorithm:EncryptionMethod];
	[self.archiveHandler EnableEncryption:self.isEncryptionEnabled];
	if (self.isEncryptionEnabled) {
		[self.archiveHandler SetDefaultPassword:[self.EncryptionPasswordField stringValue]];
	}
}

- (void)SetupTarHandler {
	// Load handler
	self.archiveHandler = [[TarHandler alloc] init];
	self.archiveHandler.delegate = self;
}

- (void)CreateArchive:(NSURL*)inputURL {
	NSString *inputPath = [inputURL path];
	
	// Figure the extension of the new archive
	NSString *archiveExtension = self.archiveFormatExtensions[self.ArchiveFormatIdx];
	
	// Be sure to create a file that doesn't already exists
	int archiveOutputPathSuffixCount = 2;
	NSURL *archiveOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@.%@",
													  inputPath, archiveExtension]];
	
	while ([archiveOutputUrl checkResourceIsReachableAndReturnError:nil]) {
		archiveOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@ %d.%@",
												   inputPath, archiveOutputPathSuffixCount++,
												   archiveExtension]];
	}
	
	NSString *archiveOutputPath = [archiveOutputUrl path];
	
	@try {
		// Setup the right archive hanlder
		[self SetupSelectedArchiveHandler];
		
		if (self.archiveHandler.SupportsEncryption) {
			NSString *Password = [self.EncryptionPasswordField stringValue];
			NSString *RepeatedPassword = [self.EncryptionRepeatField stringValue];
			if (Password.length > 0) {
				if (![Password isEqualToString:RepeatedPassword]) {
					NSAlert *alert = [[NSAlert alloc] init];
					[alert setAlertStyle:NSAlertStyleWarning];
					[alert setMessageText:@"Passwords do not match"];
					[alert setInformativeText:
					 @"To use encryption, repeating the password correctly is required to ensure no mistake is made."];
					[alert addButtonWithTitle:@"Don't encrypt"];
					[alert addButtonWithTitle:@"Cancel"];
					NSModalResponse res = [alert runModal];
					if (res == 1001) {
						return;
					}
				}
			}
		}

		// Create & Open archive
		bool ok = [self.archiveHandler OpenArchive:archiveOutputPath readOnly:FALSE];
		if (!ok) {
			NSString *error = [self.archiveHandler GetError];
			NSLog(@"Error opening archive: %@", error);
			[NSException raise:@"Error opening archive" format:@"%@", error];
		}

		// Show progress window
		[self OpenProgressWindow:[NSString stringWithFormat:@"Archiving \"%@\"", inputPath]
				 taskDescription:@"Preparing..."];
		
		// Add selected in archive (in seperate thread)
		void (^AddToArchiveBlock)(void) = ^{
			@try {
				if (inputURL.hasDirectoryPath) {
					// Add directory
					[self.archiveHandler AddDir:inputPath entryName:[inputURL lastPathComponent]];
					[self WalkDirToArchive:inputPath baseEntryName:[inputURL lastPathComponent]];
				}
				else {
					// Update task on progress window
					[self onArchiveTaskChanged:[NSString stringWithFormat:@"Adding \"%@\"", inputPath]];
					// Add file
					[self.archiveHandler AddFile:inputPath entryName:[inputURL lastPathComponent]];
				}

				bool ok = [self.archiveHandler CloseArchive];

				// Close dialog
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.progressController close];

					// Check for errors
					if (!ok) {
						NSString *error = [self.archiveHandler GetError];
						NSLog(@"Error closing archive: %@", error);
						[NSException raise:@"Error closing archive" format:@"%@", error];
					}
					else {
						if (self.DelAfterCompCheckbox.state == NSControlStateValueOn) {
							NSLog(@"Deleting input files because DelAfterCompCheckbox is checked");
							[self RmFileOrThrow:inputPath];
						}
					}

					NSAlert *alert = [[NSAlert alloc] init];
					[alert setMessageText:@"Success"];
					[alert setInformativeText:[NSString stringWithFormat:@"Archive created at \"%@\"", archiveOutputPath]];
					[alert runModal];
				});
			} @catch (NSException *exception) {
				[self RmFileOrThrow:archiveOutputPath];
				dispatch_sync(dispatch_get_main_queue(), ^{
					NSAlert *alert = [[NSAlert alloc] init];
					[alert setAlertStyle:NSAlertStyleCritical];
					[alert setMessageText:exception.name];
					[alert setInformativeText:exception.reason];
					[alert runModal];
				});
			} @finally {
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.progressController close];
				});
			}
		};

		NSThread *AddToArchiveThread = [[NSThread alloc] initWithBlock:AddToArchiveBlock];
		[AddToArchiveThread start];
	} @catch (NSException *exception) {
		[self RmFileOrThrow:archiveOutputPath];
		
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setAlertStyle:NSAlertStyleCritical];
		[alert setMessageText:exception.name];
		[alert setInformativeText:exception.reason];
		[alert runModal];
	}
}

- (void)ExtractArchive:(NSURL*)archiveURL {
	NSString *archivePath = [archiveURL path];
	NSString *selectedPathWithoutExt = [[archiveURL path] stringByDeletingPathExtension];
	
	NSString *outputPath;
	NSError* error;
	
	@try {
		// Setup Archive Handler
		[self SetupSelectedArchiveHandler];
		
		// Open archive
		bool ok = [self.archiveHandler OpenArchive:archivePath readOnly:TRUE];
		if (!ok) {
			NSString *error = [self.archiveHandler GetError];
			NSLog(@"Error opening archive: %@", error);
			[NSException raise:@"Error opening archive" format:@"%@", error];
		}
		
		ok = [self.archiveHandler Check];
		if (!ok) {
			[NSException raise:@"Error checking archive" format:@"An error occured while checking the archive"];
		}
		
		// Choose output path
		if (self.archiveHandler.NumOfEntries == 1) {
			outputPath = selectedPathWithoutExt;
		}
		else {
			int outputPathSuffixCount = 2;
			NSURL *outputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@", selectedPathWithoutExt]];
			while ([outputUrl checkResourceIsReachableAndReturnError:nil]) {
				outputUrl = [NSURL fileURLWithPath:
							 [NSString stringWithFormat:@"%@ %d", selectedPathWithoutExt, outputPathSuffixCount++]];
			}
			
			outputPath = [outputUrl path];
			
			// Create output folder
			bool okMkdir = [[NSFileManager defaultManager] createDirectoryAtPath:outputPath withIntermediateDirectories:NO attributes:nil error:&error];
			if (!okMkdir) {
				NSLog(@"Error creating folder at %@: %@", outputPath, error.localizedDescription);
				[NSException raise:@"Error creating folder at %@" format:@"%@", error.localizedDescription];
			}
		}
		
		// Show progress window
		[self OpenProgressWindow:[NSString stringWithFormat:@"Extracting \"%@\"", archivePath]
				 taskDescription:@"Preparing..."];

		// Extract all entries (in seperate thread)
		void (^ArchiveExtractBlock)(void) = ^{
			NSError *error;
			bool errorOccured = FALSE;
			
			@try {
				[self.archiveHandler ExtractAll:outputPath];
			} @catch (NSException *exception) {
				dispatch_sync(dispatch_get_main_queue(), ^{
					NSAlert *alert = [[NSAlert alloc] init];
					[alert setAlertStyle:NSAlertStyleCritical];
					[alert setMessageText:exception.name];
					[alert setInformativeText:exception.reason];
					[alert runModal];
				});
				
				errorOccured = TRUE;
			}
			@finally{
				[self.archiveHandler CloseArchive];
				
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.progressController close];
				});
			}
			
			if (self.archiveHandler.isOperationCanceled || errorOccured) {
				if (self.archiveHandler.isOperationCanceled)
					NSLog(@"Cancelling operation...");
				
				// Delete output dir
				bool okRmOutput = [[NSFileManager defaultManager] removeItemAtPath:outputPath error:&error];
				if (!okRmOutput) {
					NSLog(@"Couldn't remove output directory: %@", outputPath);
				}
				
				return;
			}
			
			dispatch_sync(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[NSAlert alloc] init];
				[alert setMessageText:@"Success"];
				[alert setInformativeText:[NSString stringWithFormat:@"Archive extracted at %@", outputPath]];
				[alert runModal];
			});
		};
		
		NSThread *ArchiveExtractThread = [[NSThread alloc] initWithBlock:ArchiveExtractBlock];
		[ArchiveExtractThread start];
	} @catch (NSException *exception) {
		if (exception.name.length > 0 && exception.reason.length > 0) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setAlertStyle:NSAlertStyleCritical];
			[alert setMessageText:exception.name];
			[alert setInformativeText:exception.reason];
			[alert runModal];
		}
	}
}

// Menubar actions
- (IBAction)FileMenuCreateArchiveClicked:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setCanChooseFiles:true];
	[openDialog setCanChooseDirectories:true];
	[openDialog setMessage:@"Choose files or folders to archive"];
	[openDialog setPrompt:@"Archive"];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		NSURL *selectedUrl = openDialog.URL;
		[self CreateArchive:selectedUrl];
	}];
}

- (IBAction)FileMenuExtractArchiveClicked:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setCanChooseFiles:true];
	[openDialog setMessage:@"Choose archive to extract"];
	[openDialog setPrompt:@"Extract"];
	
	// FIX: Using it, files with greek letters are not selectable even if they have the .zip suffix
	// [openDialog setAllowedFileTypes:[NSArray arrayWithObjects:@"zip", nil]];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK)
			return;
		
		NSURL *selectedUrl = openDialog.URL;
		[self ExtractArchive:selectedUrl];
	}];
}

- (void)ArchiveFormatHandleChange {
	[self SetupSelectedArchiveHandler];
	
	int SelectedArFormatIdx = (int) self.ArchiveFormatSelector.indexOfSelectedItem;
	if (SelectedArFormatIdx != self.ArchiveFormatIdx) {
		[self.ArchiveFormatSelector selectItemAtIndex:self.ArchiveFormatIdx];
	}
	
	// Update userdefaults
	[[NSUserDefaults standardUserDefaults] setInteger:self.ArchiveFormatIdx forKey:ArchiveFormatPrefKey];
	
	// Update UI
	if (self.archiveHandler.SupportsCompression) {
		[self.CompressionMethodSlider 	setEnabled:TRUE];
	}
	else {
		[self.CompressionMethodSlider 	setEnabled:FALSE];
	}
	
	if (self.archiveHandler.SupportsEncryption) {
		[self.EncryptionPasswordField 	setEnabled:TRUE];
		[self.EncryptionRepeatField 	setEnabled:TRUE];
		[self CheckEncryptionEnabled];
	}
	else {
		[self.EncryptionPasswordField 	setEnabled:FALSE];
		[self.EncryptionRepeatField 	setEnabled:FALSE];
		[self.EncryptionAlgorithmPopup 	setEnabled:FALSE];
	}
}

- (IBAction)ArchiveFormatChanged:(id)sender {
	int ArFormatsLength = (int) _archiveFormats.count - 1;
	int SelectedArFormatIdx = (int) self.ArchiveFormatSelector.indexOfSelectedItem;
	
	if (SelectedArFormatIdx > ArFormatsLength) {
		NSLog(@"SelectedArFormatIdx is greater than the length of supported archive formats: %i", SelectedArFormatIdx);
		return;
	}
	
	self.ArchiveFormatIdx = SelectedArFormatIdx;
	NSLog(@"Changed archive format: %i (%@)", SelectedArFormatIdx, self.archiveFormats[SelectedArFormatIdx]);
	
	[self ArchiveFormatHandleChange];
}

- (IBAction)CompressionMethodSliderChanged:(id)sender {
	int CompressionMethodValue = self.CompressionMethodSlider.intValue;
	int CompressionMethodsLength = (int) self.compressionMethods.count - 1;
	int SliderBlock = (int) self.CompressionMethodSlider.maxValue / CompressionMethodsLength;
	
	int CompressionMethodIdx = CompressionMethodValue / SliderBlock;
	if (CompressionMethodIdx > CompressionMethodsLength) {
		NSLog(@"CompressionMethodIdx is greater than the length of available compression methods: %i", CompressionMethodIdx);
		return;
	}
	
	NSString *CompressionMethodText = self.compressionMethods[CompressionMethodIdx];
	
	NSLog(@"Compression Method Changed: %i (%@)", CompressionMethodIdx, CompressionMethodText);
	
	// Update UI
	self.CompressionMethodText.stringValue = [NSString stringWithFormat:@"Method: %@", CompressionMethodText];
	
	// Update variable
	self.CompressionMethodIdx = CompressionMethodIdx;
}

- (void)CheckEncryptionEnabled {
	NSString *Password = [self.EncryptionPasswordField stringValue];
	NSString *RepPassword = [self.EncryptionRepeatField stringValue];
	
	bool isPasswordValid = Password.length > 0;
	bool doPasswordsMatch = [Password isEqualToString:RepPassword];
	
	bool isEncryptionEnabled = FALSE;
	
	if (isPasswordValid) {
		if (doPasswordsMatch) {
			[self.EncryptionPasswordValidLock setImage:[NSImage imageWithSystemSymbolName:@"lock" accessibilityDescription:nil]];
			[self.EncryptionRepeatValid setImage:[NSImage imageWithSystemSymbolName:@"checkmark.circle.fill" accessibilityDescription:nil]];
			[self.EncryptionRepeatValid	 setContentTintColor:[NSColor systemGreenColor]];
			
			isEncryptionEnabled = TRUE;
		}
		else {
			[self.EncryptionRepeatValid setImage:[NSImage imageWithSystemSymbolName:@"exclamationmark.circle.fill" accessibilityDescription:@"Passwords do not match"]];
			[self.EncryptionRepeatValid	setContentTintColor:[NSColor systemOrangeColor]];
		}
	}
	else {
		[self.EncryptionRepeatValid setImage:nil];
		[self.EncryptionPasswordValidLock setImage:[NSImage imageWithSystemSymbolName:@"lock.open" accessibilityDescription:nil]];
	}
	
	if (isEncryptionEnabled != self.isEncryptionEnabled) {
		self.isEncryptionEnabled = isEncryptionEnabled;
		
		NSString* path = [[NSBundle mainBundle] pathForResource:
						  isEncryptionEnabled ? @"encryption_enabled" : @"encryption_disabled" ofType:@"mp3"];
		NSURL* file = [NSURL fileURLWithPath:path];
		
		self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:nil];
		[self.audioPlayer prepareToPlay];
		[self.audioPlayer play];
		
		NSLog(@"Encryption has been %@", isEncryptionEnabled ? @"enabled" : @"disabled");
	}
	
	[_EncryptionAlgorithmPopup setEnabled:isEncryptionEnabled];
}

- (void)controlTextDidChange:(NSNotification *)obj {
	// If the sender is password or repeat password field
	if (obj.object == self.EncryptionPasswordField ||
		obj.object == self.EncryptionRepeatField)
	{
		[self CheckEncryptionEnabled];
	}
}

- (IBAction)EncryptionAlgorithmChanged:(id)sender {
	int EncAlgorithmsLength = (int) self.encryptionAlgorithms.count - 1;
	int SelectedEncAlgorithmIdx = (int) self.EncryptionAlgorithmPopup.indexOfSelectedItem;
	
	if (SelectedEncAlgorithmIdx > EncAlgorithmsLength) {
		NSLog(@"SelectedEncAlgorithmIdx is greater than the length of available compression algorithms: %i", SelectedEncAlgorithmIdx);
		return;
	}
	
	NSLog(@"Changed encryption algorithm: %i (%@)", SelectedEncAlgorithmIdx, self.encryptionAlgorithms[SelectedEncAlgorithmIdx]);
	self.EncryptionAlgorithmIdx = SelectedEncAlgorithmIdx;
}

- (IBAction)ExcludeMacResForksCheckboxChanged:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:
	 self.ExcludeMacResForksCheckbox.state == NSControlStateValueOn forKey:ExcludeMacResForksPrefKey];
}

- (IBAction)DelAfterCompCheckboxChanged:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:
	 self.DelAfterCompCheckbox.state == NSControlStateValueOn forKey:DelFilesAfterCompPrefKey];
}

@end
