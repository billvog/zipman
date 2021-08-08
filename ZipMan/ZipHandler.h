//
//  ZipHandler.h
//  This class handles all the Zip operations
//
//  Created by  Βασίλης Βογιατζής on 6/8/21.
//

#import <Foundation/Foundation.h>
#include <zip.h>

#import "BaseArchiveHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZipHandler: BaseArchiveHandler
@property (nonatomic, weak) id <BaseArchiveHandlerDelegate> delegate;
@property (nonatomic, readonly) zip_t*				Zip;
@property (nonatomic, readonly) int 				ZipErrorCode;
@property (nonatomic, readonly) zip_int32_t 		CompressionLevel;
@property (nonatomic, readonly) BOOL 				isEncryptionEnabled;
@property (nonatomic, readonly) NSString* 			DefaultPassword;
@property (nonatomic, readonly) zip_uint16_t 		EncryptionAlgorithm;

// Zip properties
@property (nonatomic, readonly) zip_int64_t 	NumOfEntries;
@property (nonatomic, readonly) zip_uint64_t 	TotalZipSize;
@property (nonatomic, readonly) NSString*		CommonEntriesPrefix;

// Settings
- (void)SetCompressionLevel:(zip_int32_t)level;
- (void)EnableEncryption:(BOOL)enabled;
- (void)setDefaultPassword:(NSString*)password;
- (void)SetEncryptionAlgorithm:(zip_uint16_t)algorithm;

// Zip events
void onZipProgress(zip_t *zip, double progress, void *ud);
int onZipCancel(zip_t *zip, void *ud);

- (NSString*)GetError;

- (BOOL)OpenZip:(NSString*)path readOnly:(BOOL)readOnly;
- (BOOL)CloseZip;
- (BOOL)Check;
- (void)AddFile:(NSString*)file entryName:(NSString*)entry;
- (void)AddDir:(NSString*)entry;
- (void)ExtractAll:(NSString*)output;
@end

NS_ASSUME_NONNULL_END
