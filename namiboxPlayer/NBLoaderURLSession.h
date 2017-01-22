//
//  NBLoaderURLSession.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "NBVideoRequestTask.h"

@protocol NBLoaderURLSessionDelegate <NSObject>

- (void)didFinishLoadingWithTask:(NBVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(NBVideoRequestTask *)task withError:(NSInteger )errorCode;

@end

@interface NBLoaderURLSession : NSURLSession <AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) NSString *playCachePath;
@property (nonatomic, strong) NBVideoRequestTask *task;
@property (nonatomic, weak  ) id<NBLoaderURLSessionDelegate> loaderURLSessionDelegate;
@property (nonatomic, assign) BOOL isDrag;
- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
