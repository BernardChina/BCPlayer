//
//  NBDownloadURLSession.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBDownloadURLSession.h"
#import "NBPlayerDefine.h"
#import "NBPlayer.h"

@interface NBDownloadURLSession()<NSURLSessionDownloadDelegate> {
    NSURLSession *session;
    NSString *_playUrl;
}

@end

@implementation NBDownloadURLSession

- (instancetype)initWidthPlayUrl:(NSString *)playUrl {
    if (self == [super init]) {
        _playUrl = playUrl;
        _startPlay = NO;
        
        [session invalidateAndCancel];
        session = nil;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.timeoutIntervalForRequest = 1000;
        session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURL * url = [NSURL URLWithString:_playUrl];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        NSURLSessionDownloadTask * downloadTask = [session downloadTaskWithRequest:request];
        
        [downloadTask resume];
    }
    return self;
}

// Handle download completion from the task
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    NSString *cachePath = cachePathForVideo(_playUrl);
    
    // Copy temporary file
    NSError * error;
    [[NSFileManager defaultManager] copyItemAtURL:location toURL:[NSURL fileURLWithPath:cachePath] error:&error];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    // Required delegate method
}

// Handle task completion
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Task %@ failed: %@", task, error);
    }
    
    // 下载完成，开始播放
    self.startPlay = YES;
    
}

// Handle progress update from the task
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // Update UI,更新进度条
    
    int64_t kReceived = downloadTask.countOfBytesReceived / 1024;
    int64_t kExpected = downloadTask.countOfBytesExpectedToReceive / 1024;
    NSString *statusString = [NSString stringWithFormat:@"%lldk of %lldk", kReceived, kExpected];
    NSLog(@"ddd: %@",statusString);
    
    double progress = (double) downloadTask.countOfBytesReceived / (double)downloadTask.countOfBytesExpectedToReceive;
    
    self.downloadProgress = progress;
    
}

@end
