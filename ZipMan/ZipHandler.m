//
//  ZipHandler.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 6/8/21.
//

#import "ZipHandler.h"

@implementation ZipHandler
@synthesize delegate;
@synthesize isOperationCanceled;

- (id)init {
	self = [super init];
	isOperationCanceled = FALSE;
	
	self.SupportsProgress = TRUE;
	self.SupportsCompression = TRUE;
	self.SupportsEncryption = TRUE;
	
	return self;
}

- (void)SetCompressionLevel:(int32_t)level {
	self.CompressionLevel = level;
}

- (void)EnableEncryption:(BOOL)enabled {
	self.isEncryptionEnabled = enabled;
}

- (void)SetDefaultPassword:(NSString*)password {
	self.DefaultPassword = password;
}

- (void)SetEncryptionAlgorithm:(uint16_t)algorithm {
	self.EncryptionAlgorithm = algorithm;
}

- (void)CancelOperation {
	isOperationCanceled = TRUE;
	zip_register_cancel_callback_with_state(self.Zip, onZipCancel, NULL, (__bridge void*)(self));
}

- (mode_t)ZipAttrToMode:(zip_uint32_t)attributes {
	return (mode_t)((attributes) >> 16L);
}

void onZipProgress(zip_t *zip, double progress, void *ud) {
	float ProgressFormed = (float)(progress * 100.0);
	ZipHandler* _self = (__bridge ZipHandler*)(ud);
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		[_self.delegate onArchiveProgress:ProgressFormed];
		if (_self.isOperationCanceled) {
			zip_register_cancel_callback_with_state(_self.Zip, &onZipCancel, nil, ud);
		}
	});
}

int onZipCancel(zip_t *zip, void *ud) {
	NSLog(@"Zip: Canceling...");
	return 1;
}

- (BOOL)OpenArchive:(NSString*)path readOnly:(BOOL)readOnly {
	self.Filename = path;
	
	const char *cPath = [path UTF8String];
	
	zip_t *zip = zip_open(cPath, readOnly ? ZIP_RDONLY : ZIP_CREATE, &_ZipErrorCode);
	if (zip == NULL) {
		return FALSE;
	}
	
	_Zip = zip;
	
	return TRUE;
}

- (BOOL)CloseArchive {
	// Register progress callback
	zip_register_progress_callback_with_state(self.Zip, 0.0, onZipProgress, NULL, (__bridge void *)(self));
	
	// Close zip
	int ok = zip_close(self.Zip);
	return ok == 0;
}

- (BOOL)Check {
	self.NumOfEntries = zip_get_num_entries(self.Zip, 0);
	NSLog(@"Zip: Found %lld entries in zip", self.NumOfEntries);
	
	bool askedForPassword = FALSE;
	self.TotalArchiveSize = 0u;
	
	// Loop though all entries in archive to check some things
	// before extracting
	for (zip_int64_t idx = 0; idx < self.NumOfEntries; idx++) {
		zip_stat_t *stat = malloc(sizeof(zip_stat_t));
		int res = zip_stat_index(self.Zip, idx, 0, stat);
		if (res == -1) {
			NSLog(@"Zip: Cannot stat idx: %lld", idx);
			continue;
		}
		
		// Append entry size to sum
		self.TotalArchiveSize += stat->size;
		
		// Check if all entries are in a single folder
		// then use that prefix to extract them all the root output path
		if (idx == 0) {
			NSString *entryName = [NSString stringWithUTF8String:stat->name];
			self.CommonEntriesPrefix = [entryName componentsSeparatedByString:@"/"][0];
		}
		else {
			NSString *entryName = [NSString stringWithUTF8String:stat->name];
			NSString *entryPrefix = [entryName componentsSeparatedByString:@"/"][0];
			if (![entryPrefix isEqualToString:self.CommonEntriesPrefix])
				self.CommonEntriesPrefix = @"";
		}
		
		// Check if is encrypted
		if (stat->encryption_method != ZIP_EM_NONE && !askedForPassword) {
			NSLog(@"Zip: Encrypted with mode: %d", stat->encryption_method);
			
			// Ask user for password
			bool isFirst = TRUE;
			do {
				if (!isFirst) {
					// Show wrong password alert
					[self.delegate onArchiveWrongPwd];
				}
				
				// Show PasswordPrompt as sheet
				NSString *password = [self.delegate onArchiveAskPwdForEncryption];
				if (password == nil) {
					isOperationCanceled = TRUE;
					return FALSE;
				}
				
				// Set password
				const char *cPassword = [password UTF8String];
				zip_set_default_password(self.Zip, cPassword);
				
				isFirst = FALSE;
				askedForPassword = TRUE;
			} while (zip_fopen_index(self.Zip, idx, 0) == NULL);
		}
	}
	
	return TRUE;
}

- (NSString*)GetError {
	if (self.Zip == NULL) {
		zip_error_t *error = malloc(sizeof(zip_error_t));
		zip_error_init_with_code(error, self.ZipErrorCode);
		return [NSString stringWithUTF8String:zip_error_strerror(error)];
	}
	else {
		return [NSString stringWithUTF8String:zip_strerror(self.Zip)];
	}
}

- (void)AddFile:(NSString*)file
	  entryName:(NSString*)entry
{
	const char *inputPath = [file UTF8String];

	// Open input file
	zip_source_t* source = zip_source_file(self.Zip, inputPath, 0, -1);
	if (source == NULL) {
		NSLog(@"Zip: Couldn't open file \"%s\" for read", inputPath);
		[NSException raise:@"Error opening file" format:@"Couldn't open file \"%s\" for read", inputPath];
	}
	
	const char *entryName = [entry UTF8String];
	zip_int64_t index = zip_file_add(self.Zip, entryName, source, ZIP_FL_OVERWRITE);
	if (index == -1) {
		zip_source_free(source);
		NSString *error = [self GetError];
		NSLog(@"Zip: Error adding file to zip: %@", error);
		[NSException raise:@"Error adding file to zip" format:@"%@", error];
	}
	
	zip_int32_t CompressionMethod;
	if (self.CompressionLevel == 0) {
		CompressionMethod = ZIP_CM_STORE;
	}
	else {
		CompressionMethod = ZIP_CM_DEFLATE;
	}
	
	// Apply compression
	int res = zip_set_file_compression(self.Zip, index, CompressionMethod, self.CompressionLevel);
	if (res != 0) {
		zip_source_free(source);
		NSString *error = [self GetError];
		NSLog(@"Zip: Error applying compression: %@", error);
		[NSException raise:@"Error applying compression" format:@"%@", error];
	}
	
	// Apply encryption (if it is enabled)
	if (self.isEncryptionEnabled) {
		res = zip_file_set_encryption(self.Zip, index, self.EncryptionAlgorithm,
									  [self.DefaultPassword UTF8String]);
		if (res != 0) {
			zip_source_free(source);
			NSString *error = [self GetError];
			NSLog(@"Zip: Error applying encryption: %@", error);
			[NSException raise:@"Error applying encryption" format:@"%@", error];
		}
	}
}

- (void)AddDir:(NSString*)dir entryName:(NSString*)entry {
	const char *cEntryName = [entry UTF8String];
	zip_int64_t idx = zip_add_dir(self.Zip, cEntryName);
	if (idx == -1) {
		const char *error_msg = zip_strerror(self.Zip);
		NSLog(@"Zip: Error adding directory: %s", error_msg);
		[NSException raise:@"Error adding directory" format:@"%s", error_msg];
	}
}

- (void)ExtractAll:(NSString*)output {
	NSError *error;
	zip_uint64_t total_size_read = 0u;
	
	for (zip_int64_t idx = 0; idx < self.NumOfEntries; idx++) {
		zip_stat_t *stat = malloc(sizeof(zip_stat_t));

		int ok = zip_stat_index(self.Zip, idx, 0, stat);
		if (ok == -1) {
			NSLog(@"Zip: Cannot stat entry at index: %lld", idx);
			continue;
		}

		NSString *currOutputPath;
		NSString *entryName = [NSString stringWithUTF8String:stat->name];
		entryName = [entryName substringFromIndex:self.CommonEntriesPrefix.length + 1];
		currOutputPath = [NSString stringWithFormat:@"%@/%@", output, entryName];

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self.delegate onArchiveTaskChanged:[NSString stringWithFormat:@"Extracting \"%@\"", currOutputPath]];
		});

		const char *cOutputPath = [currOutputPath UTF8String];

		bool isFolder = stat->name[strlen(stat->name) - 1] == '/';
		if (isFolder) {
			// If entry is folder then just create a folder
			bool okMkdir = [[NSFileManager defaultManager] createDirectoryAtPath:currOutputPath withIntermediateDirectories:YES attributes:nil error:&error];
			if (!okMkdir) {
				NSLog(@"Zip: Error creating folder at %@: %@", output, error.localizedDescription);
				[NSException raise:@"Error creating folder at %@" format:@"%@", error.localizedDescription];
			}

			NSLog(@"Zip: Created folder: %s", stat->name);
		}
		else {
			// Create all parent folders
			NSString *outputParentFolders = [currOutputPath stringByDeletingLastPathComponent];
			bool okMkdir = [[NSFileManager defaultManager] createDirectoryAtPath:outputParentFolders
													 withIntermediateDirectories:YES attributes:nil error:&error];
			if (!okMkdir) {
				NSLog(@"Zip: Error creating folder at \"%@\": %@", output, error.localizedDescription);
				[NSException raise:@"Error creating folder at \"%@\"" format:@"%@", error.localizedDescription];
			}

			// Get entry mode
			zip_uint32_t entry_attr;
			zip_uint8_t opsys = ZIP_OPSYS_DEFAULT;
			ok = zip_file_get_external_attributes(self.Zip, idx, 0, &opsys, &entry_attr);
			if (ok == -1) {
				NSLog(@"Zip: Error getting external attributes of %@: %@", entryName, [self GetError]);
				[NSException raise:@"Error getting external attributes of entry" format:@"%@", [self GetError]];
			}
			
			// Convert attributes to mode_t
			mode_t output_mode = [self ZipAttrToMode:entry_attr];
			
			// Open output file
			FILE *output_file;
			int output_fd = open(cOutputPath, O_WRONLY | O_CREAT, output_mode);
			output_file = fdopen(output_fd, "wb");
			if (output_file == NULL) {
				const char *error_msg = strerror(errno);
				NSLog(@"Zip: Cannot create file at \"%s\": %s", cOutputPath, error_msg);
				[NSException raise:
				   [NSString stringWithFormat:@"Failed creating file \"%s\"", cOutputPath]
							format:@"%s", error_msg];
			}

			// Open file in zip
			zip_file_t *file = zip_fopen_index(self.Zip, idx, 0);
			if (file == NULL) {
				fclose(output_file);

				const char *error_msg = zip_strerror(self.Zip);
				NSLog(@"Zip: Error accessing file %s [%lld]: %s", stat->name, idx, error_msg);
				[NSException raise:@"Error accessing file in archive" format:@"%s", error_msg];
			}

			// Write file to output
			zip_uint64_t bytes_left = stat->size;
			zip_uint64_t readchunk_size = 524288u;
			char buffer[readchunk_size];

			while (bytes_left > 0) {
				if (self.isOperationCanceled)
					break;

				if (readchunk_size > bytes_left)
					readchunk_size = bytes_left;

				zip_int64_t bytes_read = zip_fread(file, buffer, readchunk_size);
				bytes_left -= bytes_read;
				total_size_read += bytes_read;

				fwrite(buffer, readchunk_size, 1, output_file);

				// Calculate progress
				float progress = ((float) total_size_read / (float) self.TotalArchiveSize) * 100.0;
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.delegate onArchiveProgress:progress];
				});

				if (self.isOperationCanceled) {
					NSLog(@"Zip: operation cancelled: received, canceling operation...");
				}
			}

			// Release resources
			fclose(output_file);
			zip_fclose(file);

			if (self.isOperationCanceled) {
				[NSException raise:@"Error extracting zip" format:@"Operation cancelled"];
			}

			NSLog(@"Zip: Created file: %s", stat->name);
		}
	}
}

@end
