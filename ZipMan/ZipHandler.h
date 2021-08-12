//
//  ZipHandler.h
//  This class handles all the zip operations using libzip
//
//  Created by  Βασίλης Βογιατζής on 6/8/21.
//

#import <Foundation/Foundation.h>
#include <zip.h>

#import "BaseArchiveHandler.h"

// Zip attributes
#define FA_RDONLY       0x01
#define FA_DIREC        0x10

NS_ASSUME_NONNULL_BEGIN

@interface ZipHandler: BaseArchiveHandler
@property (nonatomic, readonly) zip_t*				Zip;
@property (nonatomic, readonly) int 				ZipErrorCode;

// Utils
- (mode_t)ZipAttrToMode:(zip_uint32_t)attributes;

// Zip events
void onZipProgress(zip_t *zip, double progress, void *ud);
int onZipCancel(zip_t *zip, void *ud);
@end

NS_ASSUME_NONNULL_END
