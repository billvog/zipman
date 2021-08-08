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
	self.ArchiveFormatIdx = ZIP_IDX;
	
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
	
	// Get prefs
	BOOL ExcludeMacResForks = [userDefaults boolForKey:ExcludeMacResForksPrefKey];
	BOOL DelFilesAfterComp = [userDefaults boolForKey:DelFilesAfterCompPrefKey];
	
	// Apply them to the UI
	[self.ExcludeMacResForksCheckbox setState:ExcludeMacResForks ? NSControlStateValueOn : NSControlStateValueOff];
	[self.DelAfterCompCheckbox setState:DelFilesAfterComp ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)OpenProgressWindow:(NSString*)title taskDescription:(NSString*)task {
	self.progressController = [[ProgressController alloc] initWithWindowNibName:@"ProgressWindow"];
	self.progressController.delegate = self;
	[self.progressController showWindow:self];
	[[self.progressController window] setTitle:title];
	[self.progressController setTaskDescription:task];
}

- (void)onOperationCanceled {
	[self.zipHandler CancelOperation];
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
		
		if ([fileUrl hasDirectoryPath]) {
			switch (self.ArchiveFormatIdx) {
				case ZIP_IDX:
					[self.zipHandler AddDir:entryName];
					break;
				case TAR_IDX:
					[self.tarHandler AddDir:fullPath entryName:entryName];
					break;
			}
			
			[self WalkDirToArchive:fullPath baseEntryName:entryName];
		}
		else {
			switch (self.ArchiveFormatIdx) {
				case ZIP_IDX:
					[self.zipHandler AddFile:fullPath entryName:entryName];
					break;
				case TAR_IDX:
					[self.tarHandler AddFile:fullPath entryName:entryName];
					break;
			}
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
		[self.progressController setTaskDescription:task];
	}
}

- (void)SetupZipHandler {
	// Load handler
	self.zipHandler = [[ZipHandler alloc] init];
	self.zipHandler.delegate = self;
	
	// Encryption Method
	zip_uint16_t EncryptionMethod;
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
	zip_int32_t CompressionLevel;
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
	[self.zipHandler SetCompressionLevel:CompressionLevel];
	[self.zipHandler SetEncryptionAlgorithm:EncryptionMethod];
	[self.zipHandler EnableEncryption:self.isEncryptionEnabled];
	if (self.isEncryptionEnabled) {
		[self.zipHandler setDefaultPassword:[self.EncryptionPasswordField stringValue]];
	}
}

- (void)SetupTarHandler {
	self.tarHandler = [[TarHandler alloc] init];
	self.tarHandler.delegate = self;
}

// Menubar actions
- (IBAction)FileMenuCreateArchiveClicked:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setCanChooseFiles:true];
	[openDialog setCanChooseDirectories:true];
	[openDialog setMessage:@"Choose files or folders to archive"];
	[openDialog setPrompt:@"Archive"];
	
//	TODO
//	[openDialog setAllowsMultipleSelection:TRUE];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		NSURL *selectedUrl = openDialog.URL;
		NSString *inputPath = [selectedUrl path];
		
		// Figure the extension of the new archive
		NSString *archiveExtension;
		switch (self.ArchiveFormatIdx) {
			case ZIP_IDX:
				archiveExtension = @"zip";
				break;
			case TAR_IDX:
				archiveExtension = @"tar";
				break;
			default:
				archiveExtension = @"zip";
				break;
		}
		
		// Be sure to create a zip file that doesn't already exists
		int archiveOutputPathSuffixCount = 2;
		NSURL *archiveOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@.%@",
														  [selectedUrl path], archiveExtension]];
		
		while ([archiveOutputUrl checkResourceIsReachableAndReturnError:nil]) {
			archiveOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@ %d.%@",
													   [selectedUrl path], archiveOutputPathSuffixCount++,
													   archiveExtension]];
		}
		
		NSString *archiveOutputPath = [archiveOutputUrl path];
		
		@try {
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

			if (self.ArchiveFormatIdx == ZIP_IDX) {
				[self SetupZipHandler];
				
				// Create & Open zip
				bool ok = [self.zipHandler OpenZip:archiveOutputPath readOnly:FALSE];
				if (!ok) {
					NSString *error = [self.zipHandler GetError];
					NSLog(@"Error opening zip: %@", error);
					[NSException raise:@"Error opening zip" format:@"%@", error];
				}
				
				// Add directory
				if (selectedUrl.hasDirectoryPath) {
					[self WalkDirToArchive:inputPath baseEntryName:[selectedUrl lastPathComponent]];
				}
				// Add file
				else {
					[self.zipHandler AddFile:inputPath entryName:[selectedUrl lastPathComponent]];
				}

				// Show progress window
				[self OpenProgressWindow:@"In Progress..."
						 taskDescription:[NSString stringWithFormat:@"Archiving \"%@\"", archiveOutputPath]];
				
				// Close & save archive (in seperate thread)
				void (^CloseSaveBlock)(void) = ^{
					bool ok = [self.zipHandler CloseZip];

					// Close dialog
					dispatch_sync(dispatch_get_main_queue(), ^{
						[self.progressController close];

						NSAlert *alert = [[NSAlert alloc] init];

						// Check for errors
						if (!ok) {
							NSString *error = [self.zipHandler GetError];
							NSLog(@"Error closing archive: %@", error);

							[alert setAlertStyle:NSAlertStyleCritical];
							[alert setMessageText:@"Error closing zip"];
							[alert setInformativeText:error];
						}
						else {
							bool isSuccess = true;
							if (self.DelAfterCompCheckbox.state == NSControlStateValueOn) {
								NSLog(@"Deleting input files because DelAfterCompCheckbox is checked");
								
								NSError *error;
								isSuccess = [[NSFileManager defaultManager] removeItemAtPath:inputPath error:&error];
								if (!isSuccess) {
									[alert setAlertStyle:NSAlertStyleCritical];
									[alert setMessageText:@"Error deleting input files"];
									[alert setInformativeText:error.localizedDescription];
								}
							}
							
							if (isSuccess) {
								[alert setMessageText:@"Success"];
								[alert setInformativeText:[NSString stringWithFormat:@"Archive created at \"%@\"", archiveOutputPath]];
							}
						}

						[alert runModal];
					});
				};

				NSThread *CloseSaveThread = [[NSThread alloc] initWithBlock:CloseSaveBlock];
				[CloseSaveThread start];
			}
			else if (self.ArchiveFormatIdx == TAR_IDX) {
				[self SetupTarHandler];
				
				// Create & Open tar
				bool ok = [self.tarHandler OpenTar:archiveOutputPath
										  readOnly:FALSE
										   useGzip:FALSE];
				if (!ok) {
					NSString *error = [self.tarHandler GetError];
					NSLog(@"Error opening tar: %@", error);
					[NSException raise:@"Error opening tar" format:@"%@", error];
				}
				
				// Add directory
				if (selectedUrl.hasDirectoryPath) {
					[self WalkDirToArchive:inputPath baseEntryName:[selectedUrl lastPathComponent]];
				}
				// Add file
				else {
					[self.tarHandler AddFile:inputPath entryName:[selectedUrl lastPathComponent]];
				}
				
				[self.tarHandler CloseTar];
			}
		} @catch (NSException *exception) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setAlertStyle:NSAlertStyleCritical];
			[alert setMessageText:exception.name];
			[alert setInformativeText:exception.reason];
			[alert runModal];
			return;
		}
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
		
		NSString *outputPath;
		
		NSURL *selectedUrl = openDialog.URL;
		NSString *selectedPathWithoutExt = [[selectedUrl path] stringByDeletingPathExtension];
		
		NSString *archivePath = [selectedUrl path];
		
		@try {
			NSError* error;
			
			// Setup Zip Handler
			[self SetupZipHandler];
			
			// Open zip
			bool ok = [self.zipHandler OpenZip:archivePath readOnly:TRUE];
			if (!ok) {
				NSString *error = [self.zipHandler GetError];
				NSLog(@"Error opening zip: %@", error);
				[NSException raise:@"Error opening zip" format:@"%@", error];
			}
			
			ok = [self.zipHandler Check];
			if (!ok) {
				[NSException raise:@"" format:@""];
			}
			
			// Choose output path
			if (self.zipHandler.NumOfEntries == 1) {
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
					 taskDescription:[NSString stringWithFormat:@"Extracting \"%@\"", archivePath]];

			// Extract all entries (in seperate thread)
			void (^ArchiveExtractBlock)(void) = ^{
				NSError *error;
				bool errorOccured = FALSE;
				
				@try {
					[self.zipHandler ExtractAll:outputPath];
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
					[self.zipHandler CloseZip];
					
					dispatch_sync(dispatch_get_main_queue(), ^{
						[self.progressController close];
					});
				}
				
				if (self.zipHandler.isOperationCanceled || errorOccured) {
					if (self.zipHandler.isOperationCanceled)
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
					[alert setInformativeText:[NSString stringWithFormat:@"Zip extracted at %@", outputPath]];
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
	}];
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
