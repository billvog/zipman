//
//  BaseArchiveHandler.h
//  This class will handle functionality that all (or the most)
//  archive handlers share. Like progress callback or asking user
//  for password
//  Created by  Βασίλης Βογιατζής on 7/8/21.
//

#import <Foundation/Foundation.h>

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

- (void)CancelOperation;
@end

NS_ASSUME_NONNULL_END
