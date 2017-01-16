//
//  NBVideoRequestTask.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBVideoRequestTask.h"
#import "NSString+NB.h"
#import "NBPlayerEnvironment.h"
#import "NBPlayerDefine.h"

@interface NBVideoRequestTask()<NSURLSessionDataDelegate>

@property (nonatomic, assign) NSUInteger      offset;

@property (nonatomic, assign) NSUInteger      videoLength;
@property (nonatomic, strong) NSString        *mimeType;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask * task;

@property (nonatomic, strong) NSMutableArray  *taskArr;

@property (nonatomic, assign) NSUInteger      downLoadingOffset;

@property (nonatomic, strong) NSFileHandle    *fileHandle;
@property (nonatomic, strong) NSString        *tempPath;

@end

@implementation NBVideoRequestTask

- (instancetype)init {
    self = [super init];
    if (self) {
        _taskArr = [NSMutableArray array];
        _tempPath = [cachePathForVideo stringByAppendingPathComponent:@"temp.mp4"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:_tempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:_tempPath contents:nil attributes:nil];
            
        } else {
            [[NSFileManager defaultManager] createFileAtPath:_tempPath contents:nil attributes:nil];
        }
        
    }
    return self;
}

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset {
    NSLog(@"%@",@"执行了seturl");
    _offset = offset;
    
    //如果建立第二次请求，先移除原来文件，再创建新的
    if (self.taskArr.count >= 1) {
        [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:_tempPath contents:nil attributes:nil];
    }
    
    _downLoadingOffset = 0;
    
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:self.url resolvingAgainstBaseURL:NO];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    
    if (offset > 0 && self.videoLength > 0) {
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)offset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    }
    
    [self.session invalidateAndCancel];
    self.session = nil;
    
    // Create a new configuration and session specifying this object as the delegate
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    self.task = [self.session dataTaskWithRequest:request];
    
    [self.task resume];
    
}

- (void)cancel {
    [self.task cancel];
    self.task = nil;
    [self.session invalidateAndCancel];
    self.session = nil;
}

#pragma mark - NSURLSessionDataDelegate

//服务器响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    NSLog(@"返回的状态：%@",response);
    
    _isFinishLoad = NO;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    
    NSDictionary *dic = (NSDictionary *)[httpResponse allHeaderFields] ;
    
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    
    NSUInteger videoLength;
    
    if ([length integerValue] == 0) {
        videoLength = (NSUInteger)httpResponse.expectedContentLength;
    } else {
        videoLength = [length integerValue];
    }
    
    self.videoLength = videoLength;
    self.mimeType = @"video/mp4";
    
    if ([self.delegate respondsToSelector:@selector(task:didReciveVideoLength:mimeType:)]) {
        [self.delegate task:self didReciveVideoLength:self.videoLength mimeType:self.mimeType];
    }
    
    [self.taskArr addObject:session];
    
    NSLog(@"%@",@"重置taskarr session");
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:_tempPath];
    
    completionHandler(NSURLSessionResponseAllow);
}

//服务器返回数据 可能会调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
//    NSLog(@"接受到数据didReceiveData: %@",dataTask);
    [self.fileHandle seekToEndOfFile];
    
    [self.fileHandle writeData:data];
//    NSLog(@"接受多少: %lu",(unsigned long)data.length);
    _downLoadingOffset += data.length;
    
    if ([self.delegate respondsToSelector:@selector(didReciveVideoDataWithTask:)]) {
        [self.delegate didReciveVideoDataWithTask:self];
    }
}

//请求完成会调用该方法，请求失败则error有值
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"connectionDidFinishLoading111: %@", self.taskArr);
    if (!error) {
        NSLog(@"connectionDidFinishLoading22222: %@", self.taskArr);
        
        if (self.taskArr.count < 2 && currentCacheType == NBPlayerCacheTypePlayWithCache) {
            _isFinishLoad = YES;
            
            NSString *movePath = self.playCachePath;
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:movePath]) {
                
                [self movePath:_tempPath toPath:movePath];
                
            } else {
                BOOL removeSuccess = [[NSFileManager defaultManager] removeItemAtPath:movePath error:nil];
                if (removeSuccess) {
                    [self movePath:_tempPath toPath:movePath];
                } else {
                    NSLog(@"cache failed");
                }
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithTask:)]) {
            [self.delegate didFinishLoadingWithTask:self];
        }
        return;
    }
    
    //网络中断：-1005
    //无网络连接：-1009
    //请求超时：-1001
    //服务器内部错误：-1004
    //找不到服务器：-1003
    //cancelled -999,手动调用了cancel
//    [self.taskArr removeObject:session];
    NSLog(@"error code :%ld",(long)error.code);
    if (error.code == -999) {
        return;
    }
    static int refreshCount = 0;
    if (refreshCount < 3) {      //网络超时，重连一次
        NSLog(@"重试下载");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self continueLoading];
        });
        refreshCount ++;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:withError:)]) {
        [self.delegate didFailLoadingWithTask:self withError:error.code];
    }
}

- (void)movePath:(NSString *)path toPath:(NSString *)toPath {
    
    BOOL isSuccess = [[NSFileManager defaultManager] copyItemAtPath:path toPath:toPath error:nil];
    if (isSuccess) {
//        [self clearData];
        NSLog(@"rename success");
    }else{
        NSLog(@"rename fail");
    }
}

- (void)continueLoading {
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:self.url resolvingAgainstBaseURL:NO];
//    actualURLComponents.scheme = @"http";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    
    [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)_downLoadingOffset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    
    [self.session invalidateAndCancel];
    self.session = nil;
    
    // Create a new configuration and session specifying this object as the delegate
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    self.task = [self.session dataTaskWithRequest:request];
    
    [self.task resume];
    
}

- (void)clearData {
    [self cancel];
    //移除文件
    [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
}

- (void)dealloc {
    NSLog(@"%@",@"NBVideoRequest dealloc");
    [self cancel];
}

@end
