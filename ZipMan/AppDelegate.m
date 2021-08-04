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
	self.CompressionMethodIdx = 3;
	self.compressionMethods = [[NSArray alloc] initWithObjects:
							   @"None", @"BZIP2", @"Deflate (default)", @"XZ", @"ZSTD", nil];
	
	// Encryption settings
	self.EncryptionAlgorithmIdx = 0;
	self.encryptionAlgorithms = [[NSArray alloc] initWithObjects:
								 @"AES-128", @"AES-192", @"AES-256", nil];
	
	[self.EncryptionAlgorithmPopup removeAllItems];
	[self.EncryptionAlgorithmPopup addItemsWithTitles:self.encryptionAlgorithms];
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
	   password:(NSString*)password {
	
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
	switch (self.CompressionMethodIdx) {
		case 1:
			CompressionMethod = ZIP_CM_STORE;
			break;
		case 2:
			CompressionMethod = ZIP_CM_BZIP2;
			break;
		case 3:
			CompressionMethod = ZIP_CM_DEFLATE;
			break;
		case 4:
			CompressionMethod = ZIP_CM_XZ;
			break;
		case 5:
			CompressionMethod = ZIP_CM_ZSTD;
			break;
		default:
			CompressionMethod = ZIP_CM_DEFAULT;
			break;
	}
	
	// Apply compression
	int res = zip_set_file_compression(zip, index, CompressionMethod, 0);
	if (res != 0) {
		zip_source_free(source);
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error applying compression: %s", error_msg);
		[NSException raise:@"Error applying compression" format:@"%s", error_msg];
	}
	
	// Apply encryption
	if (password != nil) {
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
		
		const char* c_password = [password UTF8String];
		res = zip_file_set_encryption(zip, index, EncryptionAlgorithm, c_password);
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
			password:(NSString*)password
{
	NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
	[dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *filename = (NSString *)obj;
		NSString *entryName = [NSString stringWithFormat:@"%@/%@", baseEntry, filename];
		NSString *full_path = [NSString stringWithFormat:@"%@/%@", path, filename];
		NSURL *fileUrl = [NSURL fileURLWithPath:full_path];
		
		if ([fileUrl hasDirectoryPath]) {
			[self ZipAddDir:zip entryName:entryName];
			[self WalkDirToZip:full_path zipFile:zip baseEntryName:entryName password:password];
		}
		else {
			[self ZipFile:full_path zipFile:zip entryName:entryName
				 password:password];
		}
	}];
}

void onZipProgress(zip_t *zip, double progress, void *ud) {
	float ProgressFormed = (float)(progress * 100.0);
	
	AppDelegate* _self = (__bridge AppDelegate*)(ud);
	if (_self.progressController != nil)
		[_self.progressController UpdateProgress:ProgressFormed];
	
	NSLog(@"Zip Progress: %.1f", ProgressFormed);
}

- (IBAction)FileMenuCreateArchiveClicked:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setCanChooseFiles:true];
	[openDialog setCanChooseDirectories:true];
	[openDialog setPrompt:@"Archive"];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		NSURL *selectedUrl = openDialog.URL;
		NSString *inputPath = [selectedUrl path];
		NSString *zipOutputPath = [NSString stringWithFormat:@"%@.zip", [selectedUrl path]];
		
		@try {
			NSString *Password = [self.EncryptionPasswordField stringValue];
			NSString *RepeatedPassword = [self.EncryptionRepeatField stringValue];
			
			if (Password.length > 0) {
				if (![Password isEqualToString:RepeatedPassword]) {
					NSLog(@"Error verifying passwords: Passwords do not match");
					[NSException raise:@"Error verifying passwords" format:@"Passwords do not match"];
				}
			}
			else {
				Password = nil;
			}
			
			// Init progress controller
			self.progressController = [[ProgressController alloc] initWithWindowNibName:@"Progress"];
			
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
					 baseEntryName:[selectedUrl lastPathComponent] password:Password];
			}
			// Add file
			else {
				[self ZipFile:inputPath zipFile:zip entryName:[selectedUrl lastPathComponent]
					 password:Password];
			}
			
			// Show progress window
			[self.progressController showWindow:self];
			
			// Register for progress callback
			zip_register_progress_callback_with_state(zip, 0.0, onZipProgress, nil, (__bridge void *)(self));
			
			
			// Close & save zip
			int res = zip_close(zip);
			if (res == -1) {
				const char *error_msg = zip_strerror(zip);
				NSLog(@"Error closing zip: %s", error_msg);
				[NSException raise:@"Error closing zip" format:@"%s", error_msg];
			}
		} @catch (NSException *exception) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setAlertStyle:NSAlertStyleCritical];
			[alert setMessageText:exception.name];
			[alert setInformativeText:exception.reason];
			[alert runModal];
			return;
		}
		@finally {
			[self.progressController close];
			self.progressController = nil;
		}
		
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:@"Success"];
		[alert setInformativeText:[NSString stringWithFormat:@"Zip created at \"%@\"", zipOutputPath]];
		[alert runModal];
	}];
}

- (IBAction)FileMenuExtractArchiveClicked:(id)sender {
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
	
	NSLog(@"Compression Method Changed: %i", CompressionMethodIdx);
	
	// Update UI
	_CompressionMethodText.stringValue = [NSString stringWithFormat:@"Method: %@",
										  [_compressionMethods objectAtIndex:CompressionMethodIdx]];
	
	// Update variable
	_CompressionMethodIdx = CompressionMethodIdx;
}

- (IBAction)PasswordFieldChanged:(id)sender {
	NSString *Password = [self.EncryptionPasswordField stringValue];
	[_EncryptionRepeatField setEnabled:(Password.length > 0)];
}

- (IBAction)RepeatPasswordFieldChanged:(id)sender {
	NSString *Password = [self.EncryptionPasswordField stringValue];
	NSString *RepPassword = [self.EncryptionRepeatField stringValue];
	
	[_EncryptionAlgorithmPopup setEnabled:[Password isEqualToString:RepPassword]];
}

- (IBAction)EncryptionAlgorithmChanged:(id)sender {
	int EncAlgorithmsLength = (int) _encryptionAlgorithms.count - 1;
	int SelectedEncAlgorithmIdx = (int) _EncryptionAlgorithmPopup.indexOfSelectedItem;
	
	if (SelectedEncAlgorithmIdx > EncAlgorithmsLength) {
		NSLog(@"SelectedEncAlgorithmIdx is greater than the length of available compression algorithms: %i", SelectedEncAlgorithmIdx);
		return;
	}
	
	NSLog(@"Changed encryption algorithm: %@", _encryptionAlgorithms[SelectedEncAlgorithmIdx]);
	_EncryptionAlgorithmIdx = SelectedEncAlgorithmIdx;
}

@end
