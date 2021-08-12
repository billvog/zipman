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
	
	self.SupportsProgress = FALSE;
	self.SupportsCompression = FALSE;
	self.SupportsEncryption = FALSE;
	
	return self;
}

- (NSString*)GetError {
	return [NSString stringWithUTF8String:
			archive_error_string(self.Tar)];
}

- (BOOL)OpenArchive:(NSString*)path readOnly:(BOOL)readOnly {
	self.isReadOnly = readOnly;
	
	const char *cPath = [path UTF8String];
	
	if (readOnly) {
		_Tar = archive_read_new();
		archive_read_support_format_tar(self.Tar);
		int ok = archive_read_open_filename(self.Tar, cPath, 16384);
		if (ok != ARCHIVE_OK) {
			return FALSE;
		}
	}
	else {
		_Tar = archive_write_new();
		archive_write_set_format_pax_restricted(self.Tar);
		int ok = archive_write_open_filename(self.Tar, cPath);
		if (ok != ARCHIVE_OK) {
			return FALSE;
		}
	}
	
	return TRUE;
}

- (BOOL)CloseArchive {
	if (self.isReadOnly) {
		archive_read_close(self.Tar);
		archive_read_free(self.Tar);
	}
	else {
		archive_write_close(self.Tar);
		archive_write_free(self.Tar);
	}

	return TRUE;
}

- (BOOL)Check {
	// Initialize values
	self.NumOfEntries = 0;
	self.TotalArchiveSize = 0u;
	
	struct archive_entry *entry;
	
	int idx = -1;
	int ok;
	while ((ok = archive_read_next_header(self.Tar, &entry)) == 0) {
		idx++;
		
		// Get entry pathname
		const char *pathname = archive_entry_pathname(entry);
		NSString *entryName = [NSString stringWithUTF8String:pathname];
		
		// Increment NumOfEntries
		self.NumOfEntries++;
		// Add file size to sum
		self.TotalArchiveSize += archive_entry_size(entry);
		
		// Calculate CommonEntriesPrefix
		if (idx == 0) {
			self.CommonEntriesPrefix = [entryName componentsSeparatedByString:@"/"][0];
		}
		else {
			NSString *entryPrefix = [entryName componentsSeparatedByString:@"/"][0];
			if (![entryPrefix isEqualToString:self.CommonEntriesPrefix])
				self.CommonEntriesPrefix = @"";
		}
	}
	
	NSLog(@"TAR: Found %lld entries in archive", self.NumOfEntries);
	
	return TRUE;
}

- (void)AddFile:(NSString*)file entryName:(NSString*)entry {
	const char *cFilePath = [file UTF8String];
	const char *cEntryName = [entry UTF8String];
	
	struct stat input_stat;
	stat(cFilePath, &input_stat);
	
	FILE *input_file = fopen(cFilePath, "rb");
	if (input_file == NULL) {
		NSString *error = [self GetError];
		NSLog(@"TAR: Error opening file %@ for reading: %@", file, error);
		[NSException raise:@"Error opening file for reading" format:@"Error opening file %@: %@", file, error];
	}
	
	// Write header
	struct archive_entry *tar_entry = archive_entry_new();
	archive_entry_set_pathname(tar_entry, cEntryName);
	[self TarEntryFromStat:tar_entry stat:input_stat];
	archive_write_header(self.Tar, tar_entry);
	
	// Write contents
	int64_t bytes_left = input_stat.st_size;
	size_t readblock_size = 524288;
	char buffer[readblock_size];
	
	while (bytes_left > 0) {
		if (readblock_size > bytes_left) {
			readblock_size = (int) bytes_left;
		}
		
		fread(buffer, readblock_size, 1, input_file);
		bytes_left -= readblock_size;
	
		la_ssize_t bytes_written = archive_write_data(self.Tar, buffer, readblock_size);
		if (bytes_written == -1) {
			NSString *error = [self GetError];
			NSLog(@"TAR: Error adding file %@ to archive: %@", file, error);
			[NSException raise:@"Error adding file to archive" format:@"Error adding file %@: %@", file, error];
		}
	}
	
	// Release resources
	fclose(input_file);
	archive_entry_free(tar_entry);
}

- (void)AddDir:(NSString*)dir entryName:(NSString*)entry {
	const char *cDirPath = [dir UTF8String];
	const char *cEntryName = [entry UTF8String];
	
	struct stat input_stat;
	stat(cDirPath, &input_stat);
	
	// Write header
	struct archive_entry *tar_entry = archive_entry_new();
	archive_entry_set_pathname(tar_entry, cEntryName);
	[self TarEntryFromStat:tar_entry stat:input_stat];
	
	int ok = archive_write_header(self.Tar, tar_entry);
	if (ok == -1) {
		NSString *error = [self GetError];
		NSLog(@"TAR: Error adding dir %@ to archive: %@", dir, error);
		[NSException raise:@"Error adding dir to archive" format:@"Failed adding dir %@ to archive: %@", dir, error];
	}
}

- (void)ExtractAll:(NSString*)output {
//	// Reset cursor to start of tar file
//	lseek((int) self.Tar->fd, 0, SEEK_SET);
//
//	NSError *error;
//	int64_t total_size_read = 0;
//
//	int ok;
//	while ((ok = th_read(self.Tar)) == 0) {
//		// From header to variables
//		char *pathname = th_get_pathname(self.Tar);
//		mode_t entry_mode = th_get_mode(self.Tar);
//		int64_t entry_size = th_get_size(self.Tar);
//
//		NSString *entryName = [NSString stringWithUTF8String:pathname];
//
//		// Output path
//		NSString *currOutputPath;
//		if (self.NumOfEntries == 1) {
//			currOutputPath = output;
//		}
//		else {
//			entryName = [entryName substringFromIndex:self.CommonEntriesPrefix.length + 1];
//			currOutputPath = [NSString stringWithFormat:@"%@/%@", output, entryName];
//		}
//
//		// Update task on progress window
//		dispatch_sync(dispatch_get_main_queue(), ^{
//			[self.delegate onArchiveTaskChanged:[NSString stringWithFormat:@"Extracting \"%@\"", currOutputPath]];
//		});
//
//		if (entry_mode & S_IFDIR) {
//			// If entry is folder then just create a folder
//			if (![[NSFileManager defaultManager] createDirectoryAtPath:currOutputPath
//										   withIntermediateDirectories:YES attributes:nil
//																 error:&error]) {
//				NSLog(@"TAR: Error creating folder at %@: %@", output, error.localizedDescription);
//				[NSException raise:@"Error creating folder at %@" format:@"%@", error.localizedDescription];
//			}
//		}
//		else {
//			// Create all parent folders
//			NSString *outputParentFolders = [currOutputPath stringByDeletingLastPathComponent];
//			if (![[NSFileManager defaultManager] createDirectoryAtPath:outputParentFolders
//										   withIntermediateDirectories:YES attributes:nil error:&error]) {
//				NSLog(@"TAR: Error creating folder at \"%@\": %@", output, error.localizedDescription);
//				[NSException raise:@"Error creating folder at \"%@\"" format:@"%@", error.localizedDescription];
//			}
//
//			char *cOutputPath = strdup([currOutputPath UTF8String]);
//
//			// Open output file
//			FILE *output_file;
//			int output_fd = open(cOutputPath, O_WRONLY | O_CREAT, entry_mode);
//			output_file = fdopen(output_fd, "wb");
//			if (output_file == NULL) {
//				const char *error_msg = strerror(errno);
//				NSLog(@"TAR: Cannot create file at \"%s\": %s", cOutputPath, error_msg);
//				[NSException raise:
//				   [NSString stringWithFormat:@"Failed creating file \"%s\"", cOutputPath]
//							format:@"%s", error_msg];
//			}
//
//			// Read contents and write to output
//			int64_t bytes_left = entry_size;
//			int readblock_size = T_BLOCKSIZE;
//			char buffer[readblock_size];
//
//			while (bytes_left > 0) {
//				if (self.isOperationCanceled)
//					break;
//
//				if (readblock_size > bytes_left) {
//					readblock_size = (int) bytes_left;
//				}
//
//				int64_t bytes_read = mytar_block_read(self.Tar, buffer);
//				if (bytes_read == -1) {
//					NSString *error = [self GetError];
//					NSLog(@"TAR: Error reading from file %s to archive: %@", pathname, error);
//					[NSException raise:@"Error extracting file from archive"
//								format:@"Error extracting file %s: %@", pathname, error];
//				}
//
//				fwrite(buffer, readblock_size, 1, output_file);
//				bytes_left -= readblock_size;
//				total_size_read += readblock_size;
//
//				// Calculate progress
//				float progress = ((float) total_size_read / (float) self.TotalArchiveSize) * 100.0;
//				dispatch_sync(dispatch_get_main_queue(), ^{
//					[self.delegate onArchiveProgress:progress];
//				});
//
//				if (self.isOperationCanceled) {
//					NSLog(@"TAR: operation cancelled: received, canceling operation...");
//				}
//			}
//
//			// Release resources
//			fclose(output_file);
//
//			// Set permissions for file
//			if ([self SetFilePerms:cOutputPath] == -1) {
//				NSLog(@"Failed setting permisions for %s", cOutputPath);
//			}
//
//			if (self.isOperationCanceled) {
//				[NSException raise:@"Error extracting tar" format:@"Operation cancelled"];
//			}
//		}
//
//		NSLog(@"TAR: Created: %s", pathname);
//	}
}

- (void)TarEntryFromStat:(struct archive_entry*)entry
					stat:(struct stat)stat
{
	// Get username from uid
	struct passwd *pws = getpwuid(stat.st_uid);
	const char *uname = pws->pw_name;
	
	// Get group id from gid
	struct group *grp = getgrgid(stat.st_gid);
	const char *gname = grp->gr_name;
	
	// Configure header
	archive_entry_set_size(entry, stat.st_size);
	archive_entry_set_uid(entry, stat.st_uid);
	archive_entry_set_uname(entry, uname);
	archive_entry_set_gid(entry, stat.st_gid);
	archive_entry_set_gname(entry, gname);
	archive_entry_set_mode(entry, stat.st_mode);
	archive_entry_set_perm(entry, stat.st_mode);
	archive_entry_set_birthtime(entry, stat.st_birthtimespec.tv_sec, stat.st_birthtimespec.tv_nsec);
	archive_entry_set_atime(entry, stat.st_atimespec.tv_sec, stat.st_atimespec.tv_nsec);
	archive_entry_set_ctime(entry, stat.st_ctimespec.tv_sec, stat.st_ctimespec.tv_nsec);
	archive_entry_set_mtime(entry, stat.st_mtimespec.tv_sec, stat.st_mtimespec.tv_nsec);
}

- (int)SetFilePerms:(char*)realname {
//	mode_t mode;
//	uid_t uid;
//	gid_t gid;
//	struct utimbuf ut;
//	char *filename;
//
//	filename = (realname ? realname : th_get_pathname(self.Tar));
//	mode = th_get_mode(self.Tar);
//	uid = th_get_uid(self.Tar);
//	gid = th_get_gid(self.Tar);
//	ut.modtime = ut.actime = th_get_mtime(self.Tar);
//
//	/* change owner/group */
//	if (geteuid() == 0)
//		if (lchown(filename, uid, gid) == -1) {
//			return -1;
//		}
//
//	/* change access/modification time */
//	if (!TH_ISSYM(self.Tar) && utime(filename, &ut) == -1) {
//		return -1;
//	}
//
//	/* change permissions */
//	if (!TH_ISSYM(self.Tar) && chmod(filename, mode) == -1) {
//		return -1;
//	}
//
	return 0;
}

@end
