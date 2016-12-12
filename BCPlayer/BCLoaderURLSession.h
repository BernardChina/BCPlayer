//
//  BCLoaderURLSession.h
//  
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "BCVideoRequestTask.h"

@protocol BCLoaderURLSessionDelegate <NSObject>

- (void)didFinishLoadingWithTask:(BCVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(BCVideoRequestTask *)task withError:(NSInteger )errorCode;

@end

@interface BCLoaderURLSession : NSURLConnection <AVAssetResourceLoaderDelegate>

@property (nonatomic, copy) NSString *playCachePath;
@property (nonatomic, strong) BCVideoRequestTask *task;
@property (nonatomic, weak  ) id<BCLoaderURLSessionDelegate> delegate;
- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end
