//
//  TarHandler.h
//  This class handles all tar operations using libtar
//
//  Created by  Βασίλης Βογιατζής on 11/8/21.
//

#import <Foundation/Foundation.h>

#include <libtar.h>
#include <errno.h>
#include <utime.h>

#import "BaseArchiveHandler.h"

/* custom altered macros for reading/writing tarchive blocks */
#define mytar_block_read(t, buf) \
	(*((t)->type->readfunc))((int)(t)->fd, (char *)(buf), T_BLOCKSIZE)
#define mytar_block_write(t, buf) \
	(*((t)->type->writefunc))((int)(t)->fd, (char *)(buf), T_BLOCKSIZE)

NS_ASSUME_NONNULL_BEGIN

@interface TarHandler : BaseArchiveHandler
@property (nonatomic, readonly) TAR *Tar;

- (int)SetFilePerms:(char*)realname;
@end

NS_ASSUME_NONNULL_END
