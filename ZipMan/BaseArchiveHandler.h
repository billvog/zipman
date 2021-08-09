//
//  BaseArchiveHandler.h
//  All the archive handlers are going to inherit from this class
//  Created by  Βασίλης Βογιατζής on 7/8/21.
//

#import <Foundation/Foundation.h>

// Archive formats
#define ZIP_IDX			0
#define TAR_IDX			1

NS_ASSUME_NONNULL_BEGIN

@protocol BaseArchiveHandlerDelegate <NSObject>
@required
- (void)onArchiveProgress:(double)progress;
- (void)onArchiveTaskChanged:(NSString*)task;

- (NSString*)onArchiveAskPwdForEncryption;
- (void)onArchiveWrongPwd;
@end


@interface BaseArchiveHandler: NSObject
@property (nonatomic, weak) id <BaseArchiveHandlerDelegate> delegate;
@property (readonly) BOOL isOperationCanceled;

@property (nonatomic) BOOL			SupportsCompression;
@property (nonatomic) BOOL			SupportsEncryption;
@property (nonatomic) int32_t		CompressionLevel;
@property (nonatomic) BOOL 			isEncryptionEnabled;
@property (nonatomic) NSString* 	DefaultPassword;
@property (nonatomic) uint16_t 		EncryptionAlgorithm;
@property (nonatomic) int64_t 		NumOfEntries;
@property (nonatomic) uint64_t 		TotalArchiveSize;
@property (nonatomic) NSString*		CommonEntriesPrefix;

- (id)init;

// Settings
- (void)SetCompressionLevel:(int32_t)level;
- (void)EnableEncryption:(BOOL)enabled;
- (void)SetDefaultPassword:(NSString*)password;
- (void)SetEncryptionAlgorithm:(uint16_t)algorithm;

- (void)CancelOperation;

- (NSString*)GetError;
- (BOOL)OpenArchive:(NSString*)path readOnly:(BOOL)readOnly;
- (BOOL)CloseArchive;
- (BOOL)Check;
- (void)AddFile:(NSString*)file entryName:(NSString*)entry;
- (void)AddDir:(NSString*)entry;
- (void)ExtractAll:(NSString*)output;
@end

NS_ASSUME_NONNULL_END
