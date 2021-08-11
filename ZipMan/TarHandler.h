//
//  TarHandler.h
//  This class handles all tar operations using libtar
//
//  Created by  Βασίλης Βογιατζής on 11/8/21.
//

#import <Foundation/Foundation.h>

#include <libtar.h>
#include <errno.h>

#import "BaseArchiveHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface TarHandler : BaseArchiveHandler
@property (nonatomic, readonly) TAR *Tar;
@end

NS_ASSUME_NONNULL_END
