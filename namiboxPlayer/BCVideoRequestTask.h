//
//  BCVideoRequestTask.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BCVideoRequestTask;

@protocol BCVideoRequestTaskDelegate <NSObject>

- (void)task:(BCVideoRequestTask *)task didReciveVideoLength:(NSUInteger)videoLength mimeType:(NSString *)mimeType;
- (void)didReciveVideoDataWithTask:(BCVideoRequestTask *)task;
- (void)didFinishLoadingWithTask:(BCVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(BCVideoRequestTask *)task withError:(NSInteger)errorCode;

@end

@interface BCVideoRequestTask : NSObject

@property (nonatomic, copy) NSString *playCachePath;
@property (nonatomic, strong, readonly) NSURL         *url;
@property (nonatomic, readonly)         NSUInteger    offset;

@property (nonatomic, readonly)         NSUInteger    videoLength;
@property (nonatomic, readonly)         NSUInteger    downLoadingOffset;
@property (nonatomic, readonly)         NSString      *mimeType;
@property (nonatomic, assign)           BOOL          isFinishLoad;

@property (nonatomic, weak)             id<BCVideoRequestTaskDelegate> delegate;

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

- (void)cancel;

- (void)continueLoading;

- (void)clearData;

@end
