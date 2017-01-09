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

static NSInteger const sPlayAfterCacheCount = 2;

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
        _downloadedIndex = [[NSFileManager defaultManager] getLastFileNameWithSuffix:@"ts" path:cachePathForVideo].integerValue;
        
        [_session invalidateAndCancel];
        _session = nil;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.timeoutIntervalForRequest = 3;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        
        [self addObserver:self forKeyPath:@"currentIndex" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
    }
    return self;
}

- (void)addDownloadTask:(NSString *)playUrl {
    _playUrl = playUrl;
    
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
        
        _downloadedIndex = [[NSFileManager defaultManager] getLastFileNameWithSuffix:@"ts" path:cachePathForVideo].integerValue;
        
        _downloadedIndex = downloadedCount == 1?0: _downloadedIndex +1;
        
        if (_downloadedIndex < self.currentIndex) {
            _downloadedIndex = self.currentIndex;
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
                // 当缓存的数量－当前播放的数量 ＝ 3.开始播放
                if (downloadedCount - self.currentIndex == sPlayAfterCacheCount) {
                    if (!self.startPlay) {
                        self.startPlay = YES;
                    }
                }
                if (self.nextTs < sPlayAfterCacheCount-1) {
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
            NSInteger sds =[[NSFileManager defaultManager] getFilesWithSuffix:@"ts" path:cachePathForVideo].count - self.currentIndex;
            BOOL s = sds < sPlayAfterCacheCount;
            if (_downloadedIndex+1 < self.taskCount && s ) {
                NSLog(@"当45666666666666666:%ld",(long)self.currentIndex);
                if (_downloadedIndex < self.currentIndex) {
                    _downloadedIndex = self.currentIndex - 1;
                    NSLog(@"开始缓存下一个111111111111：%ld",(long)self.nextTs);
                }
                if (self.nextTs != _downloadedIndex +1) {
                    self.nextTs = _downloadedIndex + 1;
                    NSLog(@"开始缓存下一个：%ld",(long)self.nextTs);
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
