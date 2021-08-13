//
//  TarHandler.h
//  This class handles all tar operations using libtar
//
//  Created by  Βασίλης Βογιατζής on 11/8/21.
//

#import <Foundation/Foundation.h>

#include <archive.h>
#include <archive_entry.h>
#include <unistd.h>
#include <sys/types.h>
#include <errno.h>
#include <utime.h>
#include <pwd.h>
#include <grp.h>

#include <libtar.h>

#import "BaseArchiveHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface TarHandler : BaseArchiveHandler
@property (nonatomic, readonly) struct archive *Tar;
@property (nonatomic) BOOL isReadOnly;

- (BOOL)ReopenArchive;

- (void)TarEntryFromStat:(struct archive_entry*)entry
					stat:(struct stat)stat;
@end

NS_ASSUME_NONNULL_END
