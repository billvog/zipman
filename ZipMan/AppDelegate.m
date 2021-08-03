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
	self.compressionMethods = [[NSArray alloc] initWithObjects:
							   @"None", @"BZIP2", @"Deflate (default)", @"XZ", @"ZSTD", nil];
	
	[self.EncryptionAlgorithmPopup removeAllItems];
	[self.EncryptionAlgorithmPopup addItemsWithTitles:[[NSArray alloc] initWithObjects:
													   @"AES-128", @"AES-192", @"AES-256", nil]];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (void)ZipFile:(NSString*)file
		  entry:(NSString*)entry
		 output:(NSString*)output {
	
	const char *inputPath = [file UTF8String];
	const char *zipOutputPath = [output UTF8String];
	
	// Create & open zip
	int error_code;
	zip_error_t *error = malloc(sizeof(zip_error_t));
	
	zip_t *zip = zip_open(zipOutputPath, ZIP_CREATE, &error_code);
	
	if (zip == NULL) {
		zip_error_init_with_code(error, error_code);
		const char *error_msg = zip_error_strerror(error);
		NSLog(@"Error opening zip: %s", error_msg);
		[NSException raise:@"Error opening zip" format:@"%s", error_msg];
	}
	
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
	
	int res = zip_set_file_compression(zip, index, CompressionMethod, 0);
	if (res != 0) {
		zip_source_free(source);
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error setting compression: %s", error_msg);
		[NSException raise:@"Error setting compression" format:@"%s", error_msg];
	}
	
	// Register for progress callback
	zip_register_progress_callback_with_state(zip, 0.0, onZipProgress, nil, (__bridge void *)(self));
	
	// Close & save zip
	res = zip_close(zip);
	if (res == -1) {
		const char *error_msg = zip_strerror(zip);
		NSLog(@"Error closing zip: %s", error_msg);
		[NSException raise:@"Error closing zip" format:@"%s", error_msg];
	}
}

void onZipProgress(zip_t *zip, double progress, void *ud) {
	float ProgressFormed = (float)(progress * 100.0);
	NSLog(@"Zip Progress: %.1f", ProgressFormed);
}

- (IBAction)FileMenuCreateArchiveClicked:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	[openDialog setCanChooseFiles:true];
	[openDialog setCanChooseDirectories:true];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		NSURL *selectedUrl = openDialog.URL;
		NSString *inputPath = [selectedUrl path];
		NSString *zipOutputPath = [NSString stringWithFormat:@"%@.zip", [selectedUrl path]];
		
		
		// Add directory
		if (selectedUrl.hasDirectoryPath) {
			// TODO
		}
		else {
			@try {
				[self ZipFile:inputPath entry:[selectedUrl lastPathComponent] output:zipOutputPath];
			} @catch (NSException *exception) {
				NSAlert *alert = [[NSAlert alloc] init];
				[alert setAlertStyle:NSAlertStyleCritical];
				[alert setMessageText:exception.name];
				[alert setInformativeText:exception.reason];
				[alert runModal];
				return;
			}
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

@end
