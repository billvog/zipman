//
//  TarHandler.h
//  This class handles all TAR operations
//
//  Created by  Βασίλης Βογιατζής on 8/8/21.
//

#import <Foundation/Foundation.h>
#import "BaseArchiveHandler.h"

#include <archive.h>
#include <archive_entry.h>

NS_ASSUME_NONNULL_BEGIN

@interface TarHandler: BaseArchiveHandler
//@property (nonatomic, weak) id <BaseArchiveHandlerDelegate> delegate;
@property (nonatomic, readonly) struct archive*	TAR;

// Tar properties
@property (nonatomic, readonly) BOOL 		isReadOnly;
@property (nonatomic, readonly) la_int64_t 	NumOfEntries;
@property (nonatomic, readonly) la_int64_t 	TotalTarSize;
@property (nonatomic, readonly) NSString*	CommonEntriesPrefix;

- (NSString*)GetError;

- (BOOL)OpenTar:(NSString*)path
	   readOnly:(BOOL)readOnly
		useGzip:(BOOL)useGzip;

- (BOOL)CloseTar;
- (BOOL)Check;
- (void)AddFile:(NSString*)file entryName:(NSString*)entry;
- (void)AddDir:(NSString*)file entryName:(NSString *)entry;
- (void)ExtractAll:(NSString*)output;
@end

NS_ASSUME_NONNULL_END
