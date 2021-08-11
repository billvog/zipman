//
//  ZipHandler.h
//  This class handles all the zip operations using libzip
//
//  Created by  Βασίλης Βογιατζής on 6/8/21.
//

#import <Foundation/Foundation.h>
#include <zip.h>

#import "BaseArchiveHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZipHandler: BaseArchiveHandler
@property (nonatomic, readonly) zip_t*				Zip;
@property (nonatomic, readonly) int 				ZipErrorCode;

// Zip events
void onZipProgress(zip_t *zip, double progress, void *ud);
int onZipCancel(zip_t *zip, void *ud);
@end

NS_ASSUME_NONNULL_END
