//
//  TarHandler.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 8/8/21.
//

#import "TarHandler.h"

@implementation TarHandler
@synthesize delegate;

- (BOOL)OpenTar:(NSString *)path
	   readOnly:(BOOL)readOnly
		useGzip:(BOOL)useGzip
{
	_isReadOnly = readOnly;
	if (readOnly) {
		_TAR = archive_read_new();
		archive_read_support_format_tar(_TAR);
		if (useGzip) {
			archive_read_support_filter_gzip(_TAR);
		}
		
		int ok = archive_read_open_filename(_TAR, [path UTF8String], 16384);
		return ok == ARCHIVE_OK;
	}
	else {
		_TAR = archive_write_new();
		archive_write_set_format_gnutar(_TAR);
		if (useGzip) {
			archive_write_add_filter_gzip(_TAR);
		}
		
		int ok = archive_write_open_filename(_TAR, [path UTF8String]);
		return ok == ARCHIVE_OK;
	}

	return TRUE;
}

- (BOOL)CloseTar {
	int ok;
	if (self.isReadOnly) ok = archive_read_free(_TAR);
	else ok = archive_write_free(_TAR);
	return ok == ARCHIVE_OK;
}

- (BOOL)Check {
	struct archive_entry *entry;
	int ok;
	BOOL isFirst = TRUE;
	
	do {
		ok = archive_read_next_header(_TAR, &entry);
		if (ok != ARCHIVE_OK) {
			break;
		}
		
		archive_read_data_skip(_TAR);

		// Increase NumOfEntries
		_NumOfEntries++;
		
		// Append entry size to sum
		_TotalTarSize += archive_entry_size(entry);
	
		if (isFirst) {
			NSString *entryName = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
			_CommonEntriesPrefix = [entryName componentsSeparatedByString:@"/"][0];
		}
		else {
			NSString *entryName = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
			NSString *entryPrefix = [entryName componentsSeparatedByString:@"/"][0];
			if (![entryPrefix isEqualToString:_CommonEntriesPrefix])
				_CommonEntriesPrefix = nil;
		}
		
		isFirst = FALSE;
	}
	while (ok == ARCHIVE_OK);

	NSLog(@"TAR: Found %lld entries", _NumOfEntries);
	
	return TRUE;
}

- (NSString *)GetError {
	return [NSString stringWithUTF8String:archive_error_string(_TAR)];
}

- (void)AddFile:(NSString *)file
	  entryName:(NSString *)entry
{
	if (_isReadOnly)
		[NSException raise:@"Error trying to write" format:@"Archive has been opened for read only"];
	
	const char *input_path = [file UTF8String];
	const char *entry_name = [entry UTF8String];
	
	// Stat file
	struct stat input_stat;
	stat(input_path, &input_stat);
	
	// Open for read
	FILE *fp = fopen(input_path, "rb");
	if (fp == NULL) {
		NSLog(@"Tar: Couldn't open file \"%s\" for read", input_path);
		[NSException raise:@"Error opening file" format:@"Couldn't open file \"%s\" for read", input_path];
	}
	
	// Create entry
	struct archive_entry *new_entry = archive_entry_new();
	archive_entry_set_pathname(new_entry, entry_name);
	archive_entry_set_size(new_entry, input_stat.st_size);
	archive_entry_set_filetype(new_entry, AE_IFREG);
	archive_entry_set_mode(new_entry, input_stat.st_mode);
	archive_entry_set_perm(new_entry, input_stat.st_mode);
	archive_entry_set_mtime(new_entry, input_stat.st_mtimespec.tv_sec,
							input_stat.st_mtimespec.tv_nsec);

	// Write header
	int ok = archive_write_header(_TAR, new_entry);
	if (ok != ARCHIVE_OK) {
		const char *error_msg = archive_error_string(_TAR);
		NSLog(@"Tar: Couldn't add file \"%s\" to archive: %s", input_path, error_msg);
		[NSException raise:@"Error adding file" format:@"%s", error_msg];
	}
	
	// Write data
	la_int64_t bytes_left = input_stat.st_size;
	la_int64_t readchunk_size = 524288;
	char buffer[readchunk_size];
	
	while (bytes_left > 0) {
		if (readchunk_size > bytes_left)
			readchunk_size = bytes_left;

		fread(buffer, readchunk_size, 1, fp);
		bytes_left -= readchunk_size;

		archive_write_data(_TAR, buffer, readchunk_size);
	}
	
	archive_write_finish_entry(_TAR);
	
	// Release resources
	fclose(fp);
	archive_entry_free(new_entry);
}

- (void)AddDir:(NSString*)file
	 entryName:(NSString*)entry {
	if (_isReadOnly)
		[NSException raise:@"Error trying to write" format:@"Archive has been opened for read only"];
	
	const char *input_path = [file UTF8String];
	const char *entry_name = [entry UTF8String];
	
	// Stat file
	struct stat input_stat;
	stat(input_path, &input_stat);
	
	// Create entry
	struct archive_entry *new_entry = archive_entry_new();
	archive_entry_set_pathname(new_entry, entry_name);
	archive_entry_set_size(new_entry, 0);
	archive_entry_set_filetype(new_entry, AE_IFDIR);
	archive_entry_set_mode(new_entry, input_stat.st_mode);
	archive_entry_set_perm(new_entry, input_stat.st_mode);
	archive_entry_set_mtime(new_entry, input_stat.st_mtimespec.tv_sec,
							input_stat.st_mtimespec.tv_nsec);

	// Write header
	int ok = archive_write_header(_TAR, new_entry);
	if (ok != ARCHIVE_OK) {
		const char *error_msg = archive_error_string(_TAR);
		NSLog(@"Tar: Couldn't add entry \"%s\" to archive: %s", entry_name, error_msg);
		[NSException raise:@"Error adding entry" format:@"%s", error_msg];
	}
	
	archive_write_finish_entry(_TAR);
	archive_entry_free(new_entry);
}

@end
