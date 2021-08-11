//
//  TarHandler.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 11/8/21.
//

#import "TarHandler.h"

@implementation TarHandler
@synthesize isOperationCanceled;

- (id)init {
	self = [super init];
	isOperationCanceled = FALSE;
	self.SupportsCompression = FALSE;
	self.SupportsEncryption = FALSE;
	return self;
}

- (NSString*)GetError {
	return [NSString stringWithUTF8String:strerror(errno)];
}

- (BOOL)OpenArchive:(NSString*)path readOnly:(BOOL)readOnly {
	int oflags;
	if (readOnly) oflags = O_RDONLY;
	else oflags = O_WRONLY | O_CREAT | O_TRUNC;
	
	int ok = tar_open(&_Tar, [path UTF8String], 0, oflags, 0644, 0);
	return ok == 0;
}

- (BOOL)CloseArchive {
	int ok = tar_append_eof(_Tar);
	if (ok == -1)
		return FALSE;
	
	ok = tar_close(_Tar);
	if (ok == -1)
		return FALSE;
	
	return TRUE;
}

- (BOOL)Check {
	// Initialize values
	self.NumOfEntries = 0;
	self.TotalArchiveSize = 0u;
	
	int idx = -1;
	int ok;
	while ((ok = th_read(_Tar)) == 0) {
		idx++;
		
		// Get entry pathname
		char *pathname = th_get_pathname(_Tar);
		NSString *entryName = [NSString stringWithUTF8String:pathname];
		
		// Increment NumOfEntries
		self.NumOfEntries++;
		// Add file size to sum
		self.TotalArchiveSize += th_get_size(_Tar);
		
		// Calculate CommonEntriesPrefix
		if (idx == 0) {
			self.CommonEntriesPrefix = [entryName componentsSeparatedByString:@"/"][0];
		}
		else {
			NSString *entryPrefix = [entryName componentsSeparatedByString:@"/"][0];
			if (![entryPrefix isEqualToString:self.CommonEntriesPrefix])
				self.CommonEntriesPrefix = @"";
		}
		
		// Skip file contents in tar file
		tar_skip_regfile(_Tar);
	}
	
	NSLog(@"TAR: Found %lld entries in archive", self.NumOfEntries);
	
	return TRUE;
}

- (void)AddFile:(NSString*)file entryName:(NSString*)entry {
	int ok = tar_append_file(_Tar, [file UTF8String], [entry UTF8String]);
	if (ok == -1) {
		NSString *error = [self GetError];
		NSLog(@"TAR: Error adding file %@ to archive: %@", file, error);
		[NSException raise:@"Error adding file to archive" format:@"Failed adding file %@ to archive: %@", file, error];
	}
}

- (void)AddDir:(NSString*)dir entryName:(NSString*)entry {
	int ok = tar_append_file(_Tar, [dir UTF8String], [entry UTF8String]);
	if (ok == -1) {
		NSString *error = [self GetError];
		NSLog(@"TAR: Error adding dir %@ to archive: %@", dir, error);
		[NSException raise:@"Error adding dir to archive" format:@"Failed adding dir %@ to archive: %@", dir, error];
	}
}

- (void)ExtractAll:(NSString*)output {
	// Reset cursor to start of tar file
	lseek((int) _Tar->fd, 0, SEEK_SET);
	
	int ok;
	while ((ok = th_read(_Tar)) == 0) {
		char *pathname = th_get_pathname(_Tar);
		NSString *entryName = [NSString stringWithUTF8String:pathname];
		
		// Output path
		NSString *currOutputPath;
		if (self.NumOfEntries == 1) {
			currOutputPath = output;
		}
		else {
			entryName = [entryName substringFromIndex:self.CommonEntriesPrefix.length + 1];
			currOutputPath = [NSString stringWithFormat:@"%@/%@", output, entryName];
		}

		// Update task on progress window
		dispatch_sync(dispatch_get_main_queue(), ^{
			[self.delegate onArchiveTaskChanged:[NSString stringWithFormat:@"Extracting \"%@\"", currOutputPath]];
		});
		
		// Extract file to output path
		char *cOutputPath = strdup([currOutputPath UTF8String]);
		ok = tar_extract_file(_Tar, cOutputPath);
		if (ok == -1) {
			NSString *error = [self GetError];
			NSLog(@"TAR: Error extracting \"%@\" from archive: %@", entryName, error);
			[NSException raise:@"Error extracting file from archive"
						format:@"Error extracting \"%@\" from archive: %@", entryName, error];
		}
	}
}

@end
