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
    NSString *_playUrl; // 其他格式的文件的url
    NSMutableArray *_urls;  // hls中ts文件的url
    NSMutableArray *_urlsWidthDownloaded; // hls中ts文件已经下载的url
}

@end

@implementation NBDownloadURLSession

- (instancetype)init {
    if (self == [super init]) {
        _startPlay = NO;
        _urls = [[NSMutableArray alloc] init];
        _urlsWidthDownloaded = [[NSMutableArray alloc] init];
        [session invalidateAndCancel];
        session = nil;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.timeoutIntervalForRequest = 1000;
        session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

//- (instancetype)initWidthPlayUrl:(NSString *)playUrl {
//    if (self == [super init]) {
//        _playUrl = playUrl;
//        _startPlay = NO;
//        
//        [session invalidateAndCancel];
//        session = nil;
//        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
//        sessionConfiguration.timeoutIntervalForRequest = 1000;
//        session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
//        
//        NSURL * url = [NSURL URLWithString:_playUrl];
//        NSURLRequest * request = [NSURLRequest requestWithURL:url];
//        NSURLSessionDownloadTask * downloadTask = [session downloadTaskWithRequest:request];
//        
//        [downloadTask resume];
//    }
//    return self;
//}

- (void)addDownloadTask:(NSString *)playUrl {
    _playUrl = playUrl;
    
    NSURL * url = [NSURL URLWithString:playUrl];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask * downloadTask = [session downloadTaskWithRequest:request];
    [_urls addObject:url];
    [downloadTask resume];
    NSLog(@"%@",@"添加task");
}

// Handle download completion from the task
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    // 存储地址
    NSString *cachePath = @"";
    
    if (currentCacheType == NBPlayerCacheTypePlayHLS) {
        NSURL *url = downloadTask.response.URL;
        [_urlsWidthDownloaded addObject:url];
        
        NSInteger index = [_urls indexOfObject:url];
        NSString *document = [[NBPlayerEnvironment defaultEnvironment] cachePath];
        cachePath =  [document stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.ts",(long)index]];
        
        self.downloadProgress = (double)_urlsWidthDownloaded.count/(double)_urls.count;
        
        if (_urlsWidthDownloaded.count == _urls.count) {
            self.startPlay = YES;
        }
        
    } else {
        cachePath = cachePathForVideo(_playUrl);
    }
    
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
        return;
    }
    
    if (currentCacheType != NBPlayerCacheTypePlayHLS) {
        // 下载完成，开始播放
        self.startPlay = YES;
    }
}

// Handle progress update from the task
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    // Update UI,更新进度条
    
    int64_t kReceived = downloadTask.countOfBytesReceived / 1024;
    int64_t kExpected = downloadTask.countOfBytesExpectedToReceive / 1024;
    NSString *statusString = [NSString stringWithFormat:@"%lldk of %lldk", kReceived, kExpected];
    NSLog(@"进度: %@",statusString);
    
    if (currentCacheType != NBPlayerCacheTypePlayHLS) {
        double progress = (double) downloadTask.countOfBytesReceived / (double)downloadTask.countOfBytesExpectedToReceive;
        
        self.downloadProgress = progress;
    }
}

- (void)cancel {
    [session invalidateAndCancel];
    session = nil;
}

- (void)dealloc {
    NSLog(@"%@",@"NBDownloadUrlSession dealloc");
    [self cancel];
}

@end
