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
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return TRUE;
}

- (void)ZipFile:(NSString*)file
		zipFile:(zip_t*)zip
	  entryName:(NSString*)entry
{
	const char *inputPath = [file UTF8String];

	// Open input file
	zip_source_t* source = zip_source_file(zip, inputPath, 0, -1);
	if (source == NULL) {
		NSLog(@"Couldn't open file \"%s\" for read", inputPath);
		[NSException raise:@"Error opening file" format:@"Couldn't open file \"%s\" for read", inputPath];
	}
	
	const char *entryName = [entry UTF8String];
	zip_int64_t index = zip_file_add(zip, entryName, source, ZIP_FL_OVERWRITE);
	if (index == -1) {
		zip_source_free(source);
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error adding file to zip: %s", error_msg);
		[NSException raise:@"Error adding file to zip" format:@"%s", error_msg];
	}
	
	zip_int32_t CompressionMethod;
	if (self.CompressionMethodIdx == 0) {
		CompressionMethod = ZIP_CM_STORE;
	}
	else {
		CompressionMethod = ZIP_CM_DEFLATE;
	}
	
	zip_uint32_t CompressionLevel;
	switch (CompressionMethod) {
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
	
	// Apply compression
	int res = zip_set_file_compression(zip, index, CompressionMethod, CompressionLevel);
	if (res != 0) {
		zip_source_free(source);
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error applying compression: %s", error_msg);
		[NSException raise:@"Error applying compression" format:@"%s", error_msg];
	}
	
	// Apply encryption (if it is enabled)
	if (self.isEncryptionEnabled) {
		NSString *Password = [self.EncryptionPasswordField stringValue];
		
		zip_uint16_t EncryptionAlgorithm;
		switch (self.EncryptionAlgorithmIdx) {
			case 1:
				EncryptionAlgorithm = ZIP_EM_AES_128;
				break;
			case 2:
				EncryptionAlgorithm = ZIP_EM_AES_192;
				break;
			case 3:
				EncryptionAlgorithm = ZIP_EM_AES_256;
				break;
			default:
				EncryptionAlgorithm = ZIP_EM_AES_128;
				break;
		}

		const char* cPassword = [Password UTF8String];
		res = zip_file_set_encryption(zip, index, EncryptionAlgorithm, cPassword);
		if (res != 0) {
			zip_source_free(source);
			const char *error_msg = zip_strerror(zip);
			NSLog(@"Error applying encryption: %s", error_msg);
			[NSException raise:@"Error applying encryption" format:@"%s", error_msg];
		}
	}
}

- (void)ZipAddDir:(zip_t*)zip
		entryName:(NSString*)entry
{
	const char *cEntryName = [entry UTF8String];
	zip_int64_t idx = zip_add_dir(zip, cEntryName);
	if (idx == -1) {
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error adding directory: %s", error_msg);
		[NSException raise:@"Error adding directory" format:@"%s", error_msg];
	}
}

- (void)WalkDirToZip:(NSString*)path
			 zipFile:(zip_t*)zip
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
		NSString *full_path = [NSString stringWithFormat:@"%@/%@", path, filename];
		NSURL *fileUrl = [NSURL fileURLWithPath:full_path];
		
		if ([fileUrl hasDirectoryPath]) {
			[self ZipAddDir:zip entryName:entryName];
			[self WalkDirToZip:full_path zipFile:zip baseEntryName:entryName];
		}
		else {
			[self ZipFile:full_path zipFile:zip entryName:entryName];
		}
	}];
}

void onZipCloseProgress(zip_t *zip, double progress, void *ud) {
	float ProgressFormed = (float)(progress * 100.0);
	
	AppDelegate* _self = (__bridge AppDelegate*)(ud);
	if (_self.progressController != nil) {
		dispatch_async(dispatch_get_main_queue(), ^{
			ProgressController *progressController = _self.progressController;
			if (progressController.isCanceled) {
				zip_register_cancel_callback_with_state(zip, &onZipCloseCancel, nil, (__bridge void*)_self);
				return;
			}
				
			[progressController UpdateProgress:ProgressFormed];
		});
	}
}

int onZipCloseCancel(zip_t *zip, void *ud) {
	NSLog(@"Canceling zip_close...");
	return 1;
}

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
		
		// Be sure to create a zip file that doesn't already exists
		int zipOutputPathSuffixCount = 2;
		NSURL *zipOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@.zip", [selectedUrl path]]];
		while ([zipOutputUrl checkResourceIsReachableAndReturnError:nil]) {
			zipOutputUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@ %d.zip", [selectedUrl path], zipOutputPathSuffixCount++]];
		}
		
		NSString *zipOutputPath = [zipOutputUrl path];
		
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

			// Create & Open zip
			const char *cZipOutputPath = [zipOutputPath UTF8String];

			int error_code;
			zip_error_t *error = malloc(sizeof(zip_error_t));

			zip_t *zip = zip_open(cZipOutputPath, ZIP_CREATE, &error_code);
			if (zip == NULL) {
				zip_error_init_with_code(error, error_code);
				const char *error_msg = zip_error_strerror(error);
				NSLog(@"Error opening zip: %s", error_msg);
				[NSException raise:@"Error opening zip" format:@"%s", error_msg];
			}

			// Add directory
			if (selectedUrl.hasDirectoryPath) {
				[self WalkDirToZip:inputPath zipFile:zip
					 baseEntryName:[selectedUrl lastPathComponent]];
			}
			// Add file
			else {
				[self ZipFile:inputPath zipFile:zip entryName:[selectedUrl lastPathComponent]];
			}

			// Show progress window
			self.progressController = [[ProgressController alloc] initWithWindowNibName:@"Progress"];
			[self.progressController showWindow:self];
			[[self.progressController window] setTitle:@"In Progress..."];
			[self.progressController setTaskDescription:[NSString stringWithFormat:@"Zipping \"%@\"", zipOutputPath]];
			
			// Register for progress callback
			zip_register_progress_callback_with_state(zip, 0.0, onZipCloseProgress, nil, (__bridge void *)(self));

			// Close & save zip (in seperate thread)
			void (^zipCloseBlock)(void) = ^{
				int res = zip_close(zip);

				// Close dialog
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.progressController close];

					NSAlert *alert = [[NSAlert alloc] init];

					// Check for errors
					if (res == -1) {
						const char *error_msg = zip_strerror(zip);
						NSLog(@"Error closing zip: %s", error_msg);

						[alert setAlertStyle:NSAlertStyleCritical];
						[alert setMessageText:@"Error closing zip"];
						[alert setInformativeText:[NSString stringWithUTF8String:error_msg]];
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
							[alert setInformativeText:[NSString stringWithFormat:@"Zip created at \"%@\"", zipOutputPath]];
						}
					}

					[alert runModal];
				});
			};

			NSThread *zipCloseThread = [[NSThread alloc] initWithBlock:zipCloseBlock];
			[zipCloseThread start];
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
//	[openDialog setAllowedFileTypes:[NSArray arrayWithObjects:@"zip", nil]];
	[openDialog setMessage:@"Choose archive to extract"];
	[openDialog setPrompt:@"Extract"];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK)
			return;
		
		NSString *outputPath;
		
		NSURL *selectedUrl = openDialog.URL;
		NSString *selectedPathWithoutExt = [[selectedUrl path] stringByDeletingPathExtension];
		
		NSString *zipPath = [selectedUrl path];
		
		@try {
			NSError* error;
			
			// Open zip
			const char *cZipPath = [zipPath UTF8String];

			int error_code;
			zip_error_t *zip_error = malloc(sizeof(zip_error_t));

			zip_t *zip = zip_open(cZipPath, ZIP_RDONLY, &error_code);
			if (zip == NULL) {
				zip_error_init_with_code(zip_error, error_code);
				const char *error_msg = zip_error_strerror(zip_error);
				NSLog(@"Error opening zip: %s", error_msg);
				[NSException raise:@"Error opening zip" format:@"%s", error_msg];
			}
			
			zip_int64_t entries_num = zip_get_num_entries(zip, 0);
			NSLog(@"Found %lld entries in zip", entries_num);
			
			bool askedForPassword = FALSE;
			
			zip_uint64_t total_zip_size = 0u;
			NSString *commonEntriesPrefix;
			
			// Loop though all entries in archive to check some things
			// before extracting
			for (zip_int64_t idx = 0; idx < entries_num; idx++) {
				zip_stat_t *stat = malloc(sizeof(zip_stat_t));
				int res = zip_stat_index(zip, idx, 0, stat);
				if (res == -1) {
					NSLog(@"Cannot stat entry at index: %lld", idx);
					continue;
				}
				
				// Append entry size to sum
				total_zip_size += stat->size;
				
				// Check if all entries are in a single folder
				// then use that prefix to extract them all the root output path
				if (idx == 0) {
					NSString *entryName = [NSString stringWithUTF8String:stat->name];
					commonEntriesPrefix = [entryName componentsSeparatedByString:@"/"][0];
				}
				else {
					NSString *entryName = [NSString stringWithUTF8String:stat->name];
					NSString *entryPrefix = [entryName componentsSeparatedByString:@"/"][0];
					if (![entryPrefix isEqualToString:commonEntriesPrefix])
						commonEntriesPrefix = nil;
				}
				
				// Check if is encrypted
				if (stat->encryption_method != ZIP_EM_NONE && !askedForPassword) {
					NSLog(@"Archive is encrypted with mode: %d", stat->encryption_method);
					
					// Show password prompt
					PasswordPromptController *pwdPromptCtrl = [[PasswordPromptController alloc] initWithWindowNibName:@"PasswordPrompt"];
					bool isFirst = TRUE;
					do {
						if (!isFirst) {
							// Show wrong password alert
							NSAlert *alert = [[NSAlert alloc] init];
							[alert setAlertStyle:NSAlertStyleCritical];
							[alert setMessageText:@"Incorrect password"];
							[alert setInformativeText:@"The provided password does not match the password used for encryption."];
							[alert runModal];
						}
						
						// Show PasswordPrompt as sheet
						[self.window beginSheet:pwdPromptCtrl.window completionHandler:nil];
						NSModalResponse returnCode = [NSApp runModalForWindow:pwdPromptCtrl.window];
						
						// Check response
						if (returnCode != NSModalResponseOK) {
							[NSException raise:@"" format:@""];
						}
						
						// Set password
						const char *password = [[pwdPromptCtrl GetPassword] UTF8String];
						zip_set_default_password(zip, password);
						
						[NSApp endSheet: pwdPromptCtrl.window];
						[pwdPromptCtrl.window orderOut:self];
						
						isFirst = FALSE;
						askedForPassword = TRUE;
					} while (zip_fopen_index(zip, idx, 0) == NULL);
				}
			}
			
			if (commonEntriesPrefix != nil) {
				NSLog(@"Found common entries prefix: %@", commonEntriesPrefix);
			}
			
			// Choose output path
			if (entries_num == 1) {
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
			self.progressController = [[ProgressController alloc] initWithWindowNibName:@"Progress"];
			[self.progressController showWindow:self];
			[[self.progressController window] setTitle:[NSString stringWithFormat:@"Extracting \"%@\"", zipPath]];

			// Extract all entries (in seperate thread)
			void (^zipExtractBlock)(void) = ^{
				NSError *error;
				zip_uint64_t total_size_read = 0u;
				
				bool isCanceled = FALSE;
				bool errorOccured = FALSE;
				
				@try {
					for (zip_int64_t idx = 0; idx < entries_num; idx++) {
						zip_stat_t *stat = malloc(sizeof(zip_stat_t));
						
						int res = zip_stat_index(zip, idx, 0, stat);
						if (res == -1) {
							NSLog(@"Cannot stat entry at index: %lld", idx);
							continue;
						}
						
						NSString *currOutputPath;
						if (entries_num == 1) {
							currOutputPath = outputPath;
						}
						else {
							NSString *entryName = [NSString stringWithUTF8String:stat->name];
							entryName = [entryName substringFromIndex:commonEntriesPrefix.length + 1];
							
							currOutputPath = [NSString stringWithFormat:@"%@/%@", outputPath, entryName];
						}
						
						dispatch_sync(dispatch_get_main_queue(), ^{
							[self.progressController setTaskDescription:[NSString stringWithFormat:@"Extracting \"%@\"...", currOutputPath]];
						});
						
						const char *cOutputPath = [currOutputPath UTF8String];
						
						bool isFolder = stat->name[strlen(stat->name) - 1] == '/';
						if (isFolder) {
							// If entry is folder then just create a folder
							bool okMkdir = [[NSFileManager defaultManager] createDirectoryAtPath:currOutputPath withIntermediateDirectories:YES attributes:nil error:&error];
							if (!okMkdir) {
								NSLog(@"Error creating folder at %@: %@", outputPath, error.localizedDescription);
								[NSException raise:@"Error creating folder at %@" format:@"%@", error.localizedDescription];
							}
							
							NSLog(@"Created folder: %s", stat->name);
						}
						else {
							// Create all parent folders
							NSString *outputParentFolders = [currOutputPath stringByDeletingLastPathComponent];
							bool okMkdir = [[NSFileManager defaultManager] createDirectoryAtPath:outputParentFolders
																	 withIntermediateDirectories:YES attributes:nil error:&error];
							if (!okMkdir) {
								NSLog(@"Error creating folder at \"%@\": %@", outputPath, error.localizedDescription);
								[NSException raise:@"Error creating folder at \"%@\"" format:@"%@", error.localizedDescription];
							}
							
							// Open output file
							FILE *fp = fopen(cOutputPath, "wb");
							if (fp == NULL) {
								const char *error_msg = strerror(errno);
								NSLog(@"Cannot create file at \"%s\": %s", cOutputPath, error_msg);
								[NSException raise:
								   [NSString stringWithFormat:@"Failed creating file \"%s\"", cOutputPath]
									  		 format:@"%s", error_msg];
							}
							
							// Open file in zip
							zip_file_t *file = zip_fopen_index(zip, idx, 0);
							if (file == NULL) {
								fclose(fp);
								
								const char *error_msg = zip_strerror(zip);
								NSLog(@"Error accessing file %s [%lld]: %s", stat->name, idx, error_msg);
								[NSException raise:@"Error accessing file in archive" format:@"%s", error_msg];
							}
							
							// Write file to output
							zip_uint64_t bytes_left = stat->size;
							zip_uint64_t readchunk_size = 524288u;
							char buffer[readchunk_size];
							
							while (bytes_left > 0) {
								if (isCanceled)
									break;
								
								if (readchunk_size > bytes_left)
									readchunk_size = bytes_left;
								
								zip_int64_t bytes_read = zip_fread(file, buffer, readchunk_size);
								bytes_left -= bytes_read;
								total_size_read += bytes_read;
								
								fwrite(buffer, readchunk_size, 1, fp);
								
								// Calculate progress
								float progress = ((float) total_size_read / (float) total_zip_size) * 100.0;
								dispatch_sync(dispatch_get_main_queue(), ^{
									[self.progressController UpdateProgress:progress];
								});
								
								if ([self.progressController isCanceled]) {
									isCanceled = TRUE;
									NSLog(@"Operation canceled!");
								}
							}
							
							// Release resources
							fclose(fp);
							zip_fclose(file);

							if (isCanceled)
								break;
							
							NSLog(@"Created file: %s", stat->name);
						}
					}
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
					zip_close(zip);
					
					dispatch_sync(dispatch_get_main_queue(), ^{
						[self.progressController close];
					});
				}
				
				if (isCanceled || errorOccured) {
					if (isCanceled)
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
			
			NSThread *zipExtractThread = [[NSThread alloc] initWithBlock:zipExtractBlock];
			[zipExtractThread start];
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

- (IBAction)CompressionMethodSliderChanged:(id)sender {
	int CompressionMethodValue = _CompressionMethodSlider.intValue;
	int CompressionMethodsLength = (int) _compressionMethods.count - 1;
	int SliderBlock = (int) _CompressionMethodSlider.maxValue / CompressionMethodsLength;
	
	int CompressionMethodIdx = CompressionMethodValue / SliderBlock;
	if (CompressionMethodIdx > CompressionMethodsLength) {
		NSLog(@"CompressionMethodIdx is greater than the length of available compression methods: %i", CompressionMethodIdx);
		return;
	}
	
	NSString *CompressionMethodText = _compressionMethods[CompressionMethodIdx];
	
	NSLog(@"Compression Method Changed: %i (%@)", CompressionMethodIdx, CompressionMethodText);
	
	// Update UI
	_CompressionMethodText.stringValue = [NSString stringWithFormat:@"Method: %@", CompressionMethodText];
	
	// Update variable
	_CompressionMethodIdx = CompressionMethodIdx;
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
	int EncAlgorithmsLength = (int) _encryptionAlgorithms.count - 1;
	int SelectedEncAlgorithmIdx = (int) _EncryptionAlgorithmPopup.indexOfSelectedItem;
	
	if (SelectedEncAlgorithmIdx > EncAlgorithmsLength) {
		NSLog(@"SelectedEncAlgorithmIdx is greater than the length of available compression algorithms: %i", SelectedEncAlgorithmIdx);
		return;
	}
	
	NSLog(@"Changed encryption algorithm: %i (%@)", SelectedEncAlgorithmIdx, _encryptionAlgorithms[SelectedEncAlgorithmIdx]);
	_EncryptionAlgorithmIdx = SelectedEncAlgorithmIdx;
}

@end
