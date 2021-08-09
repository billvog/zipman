//
//  BaseArchiveHandler.m
//  ZipMan
//
//  Created by  Βασίλης Βογιατζής on 7/8/21.
//

#import "BaseArchiveHandler.h"

@implementation BaseArchiveHandler

- (void)CancelOperation {
	_isOperationCanceled = TRUE;
}

- (id)init { return self; }
- (void)SetCompressionLevel:(int32_t)level {}
- (void)EnableEncryption:(BOOL)enabled {}
- (void)SetDefaultPassword:(NSString*)password {}
- (void)SetEncryptionAlgorithm:(uint16_t)algorithm {}
- (NSString*)GetError { return @""; }
- (BOOL)OpenArchive:(NSString*)path readOnly:(BOOL)readOnly { return false; }
- (BOOL)CloseArchive { return false; }
- (BOOL)Check { return false; }
- (void)AddFile:(NSString*)file entryName:(NSString*)entry {}
- (void)AddDir:(NSString*)entry {}
- (void)ExtractAll:(NSString*)output {}

@end
