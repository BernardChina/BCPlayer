//
//  NBVideoRequestTask.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class NBVideoRequestTask;

@protocol NBVideoRequestTaskDelegate <NSObject>

- (void)task:(NBVideoRequestTask *)task didReciveVideoLength:(NSUInteger)videoLength mimeType:(NSString *)mimeType;
- (void)didReciveVideoDataWithTask:(NBVideoRequestTask *)task;
- (void)didFinishLoadingWithTask:(NBVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(NBVideoRequestTask *)task withError:(NSInteger)errorCode;

@end

@interface NBVideoRequestTask : NSObject

@property (nonatomic, strong) NSString *playCachePath;
@property (nonatomic, strong) NSURL         *url;
@property (nonatomic, readonly)         NSUInteger    offset;

@property (nonatomic, readonly)         NSUInteger    videoLength;
@property (nonatomic, readonly)         NSUInteger    downLoadingOffset;
@property (nonatomic, readonly)         NSString      *mimeType;
@property (nonatomic, assign)           BOOL          isFinishLoad;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;


@property (nonatomic, weak)             id<NBVideoRequestTaskDelegate> delegate;


- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

- (void)cancel;

- (void)continueLoading;

- (void)clearData;

@end
