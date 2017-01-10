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
#import "NBPlayerM3U8Handler.h"
#import "HTTPServer.h"
#import "NBPlayerEnvironment.h"
#import "NSFileManager+NB.h"

static NSInteger sPlayAfterCacheCount = 10;

@interface NBDownloadURLSession()<NSURLSessionDownloadDelegate> {
    NSURLSession *_session;
    NSString *_playUrl; // 其他格式的文件的url
    NSInteger _downloadedIndex; // 已经下载的index
}

@property (nonatomic, strong) NSString *errorUrlString; // 下载失败的url
@property (nonatomic, assign) int retryCount;   // 重试下载次数

@end

@implementation NBDownloadURLSession

- (instancetype)init {
    if (self == [super init]) {
        _startPlay = NO;
//        _downloadedIndex = [[NSFileManager defaultManager] getLastFileNameWithSuffix:@"ts" path:cachePathForVideo].integerValue;
        
        [_session invalidateAndCancel];
        _session = nil;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.timeoutIntervalForRequest = 3;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        
        [self addObserver:self forKeyPath:@"currentIndex" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
    }
    return self;
}

- (void)addDownloadTask:(NSString *)playUrl withIndex:(NSInteger)index {
    _playUrl = playUrl;
    _downloadedIndex = index;
    sPlayAfterCacheCount = self.taskCount - 1;
    
    NSURL * url = [NSURL URLWithString:playUrl];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask * downloadTask = [_session downloadTaskWithRequest:request];
    [downloadTask resume];
    NSLog(@"%@ %@",@"添加task",playUrl);
}

// Handle download completion from the task
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    // 存储地址
    NSString *cachePath = @"";
    
    if (isHLS) {
        
        NSUInteger downloadedCount = [[NSFileManager defaultManager] getFilesWithSuffix:@"ts" path:cachePathForVideo].count + 1;
        
        if (self.currentIndex > 0 && self.nextTs == self.currentIndex) {
            self.startPlay = YES;
        }
        
        cachePath =  [cachePathForVideo stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.ts",(long)_downloadedIndex]];
        
        self.downloadProgress = (double)downloadedCount/(double)self.taskCount;
        
        switch (currentCacheType) {
            case NBPlayerCacheTypePlayAfterCache: {
                if (downloadedCount == self.taskCount) {
                    self.startPlay = YES;
                } else {
                    self.nextTs = _downloadedIndex + 1;
                }
            }
            break;
                
            case NBPlayerCacheTypePlayWithCache: {
                
                if (downloadedCount - self.currentIndex == 2) {
                    if (!self.startPlay) {
                        self.startPlay = YES;
                    }
                }
                
                if (self.nextTs < 1) {
                    self.nextTs = _downloadedIndex + 1;
                }
            }
            break;
                
            default:
                break;
        }
        
    } else {
        cachePath = saveCachePathForVideo(_playUrl);
    }
    
    // Copy temporary file
    NSError * error;
    // move
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:cachePath] error:&error];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    // Required delegate method
}

// Handle task completion
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Task %@ failed: %@", task, error);
        if (![self.errorUrlString isEqualToString:task.currentRequest.URL.absoluteString]) {
            self.retryCount = 0;
        }
        NSData *data = error.userInfo[@"NSURLSessionDownloadTaskResumeData"];
        if (!data || (self.retryCount >= 3 && self.downloadFailed)) {
            self.downloadFailed(error, task, _nextTs);
        }
        
        if (data && self.retryCount < 3) {
            NSLog(@"重新下载");
            self.errorUrlString = task.currentRequest.URL.absoluteString;
            NSURLSessionDownloadTask * downloadTask=[_session downloadTaskWithResumeData:data];
            [downloadTask resume];
            self.retryCount ++;
        }
        
        return;
    }
    
    if (!isHLS) {
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
//    NSLog(@"进度: %@",statusString);
    
    if (!self.downloadProgress) {
        self.downloadProgress = 0;
    }
    
    if (!isHLS) {
        double progress = (double) downloadTask.countOfBytesReceived / (double)downloadTask.countOfBytesExpectedToReceive;
        
        self.downloadProgress = progress;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == DownloadKVOContext) {
        if ([keyPath isEqualToString:@"currentIndex"]) {
            // 当拿到index的时候，首先判断，当前index是否下载了，如果没有下载则直接下载，如果已经下载，判断预下载逻辑
            
            if (![[NSFileManager defaultManager] haveDownloaded:[NSString stringWithFormat:@"%ld.ts",(long)self.currentIndex] withPath:cachePathForVideo]) {
                if (self.nextTs != self.currentIndex) {
                    self.nextTs = self.currentIndex;
                }
                return;
            }
            
            // 如果已经下载。
            // 1. 依当前index为基本，后面一个是否下载，如果没有下载，就进行下载，如果下载了，直接return
            
            for (int i= 0; i < sPlayAfterCacheCount; i++) {
                long preDownloadIndex = self.currentIndex + i;
                if (preDownloadIndex < self.taskCount && ![[NSFileManager defaultManager] haveDownloaded:[NSString stringWithFormat:@"%ld.ts",preDownloadIndex] withPath:cachePathForVideo]) {
                    // 如果想等说明正在下载。
                    if (preDownloadIndex == _downloadedIndex) {
                        return;
                    }
                    self.nextTs = preDownloadIndex;
                    return;
                }
            }
            
            return;
        }
    }
}

- (void)cancel {
    NSLog(@"%@",@"cancel 11111111111111");
    [_session invalidateAndCancel];
    _session = nil;
}

- (void)dealloc {
    NSLog(@"%@",@"NBDownloadUrlSession dealloc");
    [self cancel];
    [self removeObserver:self forKeyPath:@"currentIndex"];
}

@end
