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

@interface NBLoaderURLSession : NSURLConnection <AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) NBVideoRequestTask *task;
@property (nonatomic, weak  ) id<NBLoaderURLSessionDelegate> delegate;
- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
