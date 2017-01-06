//
//  NBPlayerM3U8Handler.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/8.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBPlayerM3U8Handler.h"
#import "NBDownloadURLSession.h"
#import "NBPlayerDefine.h"
#import "NSFileManager+NB.h"

#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <unistd.h>
#import <dlfcn.h>
#import <notify.h>

@interface NBPlayerM3U8Handler()

@property (nonatomic, strong) NSMutableArray *segments;
@property (nonatomic, strong) NSMutableArray *durations;
@property (nonatomic, strong) NSString *url;

@end

@implementation M3U8SegmentInfo

@end

@implementation NBPlayerM3U8Handler
SCNetworkConnectionFlags connectionFlags;
SCNetworkReachabilityRef reachability;

- (instancetype)init {
    if (self == [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTimeChanged:) name:kNBPlayerCurrentTimeChangedNofification object:nil];
        
    }
    return self;
}

- (void)praseUrl:(NSString *)urlstr {
    self.url = urlstr;
    [self.loadSession addObserver:self forKeyPath:@"nextTs" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
    
    self.durations = [[NSMutableArray alloc] init];
    
    NSArray *fileList = [[NSFileManager defaultManager] getFilesWithSuffix:@"ts" path:cachePathForVideo];
    NSArray *m3u8FileList = [[NSFileManager defaultManager] getFilesWithSuffix:@"m3u8" path:cachePathForVideo];
    
    if (m3u8FileList.count > 0 && fileList.count > 0) {
        
        NSString *path = [cachePathForVideo stringByAppendingPathComponent:cacheVieoName];
        NSURL *pathUrl = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        NSStringEncoding encoding;
        /** 获取到返回的响应字符串，其中包含该视频流的信息 */
        NSString *data = [[NSString alloc] initWithContentsOfURL:pathUrl
                                                    usedEncoding:&encoding
                                                           error:&error];
        NSString* remainData =data;
        NSArray *array = [remainData componentsSeparatedByString:@"#EXTINF:"];
        
        __block double duration = 0;
        
        [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx != 0) {
                NSArray *temp = [obj componentsSeparatedByString:@","];
                M3U8SegmentInfo * segment = [[M3U8SegmentInfo alloc]init];
                segment.duration = [temp[0] doubleValue];
                
                [self.durations addObject:@(segment.duration)];
                
                duration += segment.duration;
            }
        }];
        
        self.loadSession.taskCount = self.durations.count;
        
        durationWithHLS = duration;
        
        NSString *lastFileName = [[NSFileManager defaultManager] getLastFileNameWithSuffix:@"ts" path:cachePathForVideo];
        
        if ([lastFileName intValue] +1 != fileList.count) {
            [[NSFileManager defaultManager] removeItemAtPath:cachePathForVideo error:nil];
            [self praseUrlFromNetWork:urlstr];
            return;
        }
        
        if (fileList.count <= self.durations.count) {
            switch (currentCacheType) {
                case NBPlayerCacheTypePlayWithCache:{
                    self.loadSession.startPlay = YES;
                    // 如果相等说明下载完成，直接return
                    if (self.durations.count == fileList.count) {
                        return;
                    }
                }
                    break;
                case NBPlayerCacheTypePlayAfterCache:{
                    if(self.durations.count == fileList.count) {
                        self.loadSession.startPlay = YES;
                        return;
                    }
                }
                    break;
                    
                default:
                    break;
            }
        }
        
    }
    [self praseUrlFromNetWork:urlstr];
}
/*
 code == 3000 网络不可用
 code == 3001 服务器返回数据为空
 code == 3002 服务器返回数据错误
 */
- (void)praseUrlFromNetWork:(NSString *)urlstr {
    // 此时判断是否有网络，如果没有网络处理，
    if (![self networkAvailable]) {
        if (self.praseFailed) {
            self.praseFailed([NSError errorWithDomain:@"网络不可用" code:3000 userInfo:nil],self.loadSession.nextTs);
        }
        return;
    }
    
    NSURL *url = [[NSURL alloc] initWithString:urlstr];
    NSError *error = nil;
    NSStringEncoding encoding;
    /** 获取到返回的响应字符串，其中包含该视频流的信息 */
    NSString *data = [[NSString alloc] initWithContentsOfURL:url
                                                usedEncoding:&encoding
                                                       error:&error];
    
    if (error) {
        if (self.praseFailed) {
            self.praseFailed(error, self.loadSession.nextTs);
        }
    }
    
    if(data == nil) {
        if (self.praseFailed) {
            self.praseFailed([NSError errorWithDomain:@"服务器返回数据为空" code:3001 userInfo:nil],self.loadSession.nextTs);
        }
        return;
    }
    
    if (![data containsString:@"#EXTINF:"]) {
        if (self.praseFailed) {
            self.praseFailed([NSError errorWithDomain:@"服务器返回数据错误" code:3002 userInfo:nil], self.loadSession.nextTs);
        }
        return;
    }
    self.segments = [[NSMutableArray alloc] init];
    NSString* remainData =data;
    NSArray *array = [remainData componentsSeparatedByString:@"#EXTINF:"];
    NSString *baseUrl = [url.scheme stringByAppendingString:[NSString stringWithFormat:@"://%@",url.host]];
    
    __block double duration = 0;
    
    [self.durations removeAllObjects];
    
    [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx != 0) {
            NSArray *temp = [obj componentsSeparatedByString:@","];
            M3U8SegmentInfo * segment = [[M3U8SegmentInfo alloc]init];
            segment.duration = [temp[0] doubleValue];
            segment.locationUrl = [self removeSpaceAndNewlineAndOtherFlag:temp[1]];
            if (!([segment.locationUrl hasPrefix:@"http"] || [segment.locationUrl hasPrefix:@"https"])) {
                
                segment.locationUrl = [baseUrl stringByAppendingString:segment.locationUrl];
            }
            
            [self.segments addObject:segment];
            [self.durations addObject:@(segment.duration)];
            
            duration += segment.duration;
        }
    }];
    
    durationWithHLS = duration;
    
    self.loadSession.taskCount = self.segments.count;
    
    NSArray *fileList = [[NSFileManager defaultManager] getFilesWithSuffix:@"ts" path:cachePathForVideo];
    
    // ==0 说明完全没有下载
    if (fileList.count == 0) {
        [self createLocalM3U8file];
        
        if (self.segments.firstObject) {
            M3U8SegmentInfo * segment = self.segments.firstObject;
            [self.loadSession addDownloadTask:segment.locationUrl];
        }
    } else if (fileList.count < self.segments.count && currentCacheType == NBPlayerCacheTypePlayAfterCache) {
        // 说明没有下载完成，只是下载了一部分或者下载完成
        M3U8SegmentInfo * segment = self.segments[fileList.count];
        [self.loadSession addDownloadTask:segment.locationUrl];
        self.loadSession.downloadProgress = (double)fileList.count/(double)self.segments.count;
    }
    
}

- (NSString *)removeSpaceAndNewlineAndOtherFlag:(NSString *)str {
    NSString *temp = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"," withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    return temp;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == DownloadKVOContext) {
        if ([object isEqual:self.loadSession] && [keyPath isEqualToString:@"nextTs"]) {
            NSInteger nextTs = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            if (self.segments.count == 0) {
                // 重新渲染
                [self praseUrlFromNetWork:self.url];
            }
            
            M3U8SegmentInfo * segment = [self.segments objectAtIndex:nextTs];
            if (segment) {
                [self.loadSession addDownloadTask:segment.locationUrl];
            }
            return;
        }
    }
}

- (void)refreshTask:(NSInteger)textTs completeWithError:(praseFailed)error {
    if (self.segments.count == 0) {
        [self praseUrlFromNetWork:self.url];
    }
    M3U8SegmentInfo * segment = [self.segments objectAtIndex:textTs];
    if (segment) {
        [self.loadSession addDownloadTask:segment.locationUrl];
    } else {
        error([NSError errorWithDomain:@"重刷数据失败" code:0 userInfo:nil], self.loadSession.nextTs);
    }
    
}

- (void)currentTimeChanged:(NSNotification *)notification {
    
    if (notification) {
        NSDictionary *dic = notification.userInfo;
        if (!dic) {
            return;
        }
        NSInteger current = [dic[@"currentTime"] integerValue];
        NSLog(@"当钱条装世界：%ld",(long)current);
        __block NSInteger currentIndex = 0;//当前播放到哪一个ts
        __block double temp = 0;
        
        [self.durations enumerateObjectsUsingBlock:^(id  _Nonnull  obj, NSUInteger idx, BOOL * _Nonnull stop) {
            temp += [obj doubleValue];
            if (current <= temp) {
                currentIndex = idx;
                *stop = YES;
                return ;
            }
        }];
        self.loadSession.currentIndex = currentIndex;
        NSLog(@"当钱播放的index：%ld",(long)currentIndex);
        
        if (currentIndex == self.durations.count - 1) {
            if (self.playFinished) {
                self.playFinished();
            }
        }
    }
}

-(NSString*)createLocalM3U8file {
    
    NSString *fullpath = [cachePathForVideo stringByAppendingPathComponent:cacheVieoName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:fullpath]) {
        saveCachePathForVideo(self.url);
    }
    
    //    NSFileManager *fileManager = [NSFileManager defaultManager];
    //    if (![fileManager fileExistsAtPath:fullpath]) {
    //        return nil;
    //    }
    
    //创建文件头部
    __block NSString* head = @"#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-ALLOW-CACHE:YES\n#EXT-X-TARGETDURATION:19\n#EXT-X-VERSION:3\n";
    
    [self.segments enumerateObjectsUsingBlock:^(M3U8SegmentInfo *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *localUrl = [httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%ld.ts",(long)idx]];
        NSString* length = [NSString stringWithFormat:@"#EXTINF:%f,\n",obj.duration];
        head = [NSString stringWithFormat:@"%@%@%@\n",head,length,localUrl];
        
    }];
    //创建尾部
    NSString* end = @"#EXT-X-ENDLIST";
    head = [head stringByAppendingString:end];
    NSMutableData *writer = [[NSMutableData alloc] init];
    [writer appendData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSError *error;
    BOOL bSucc =[writer writeToFile:fullpath options:(NSDataWritingAtomic )  error:&error];
    
    
    if(bSucc) {
        NSLog(@"create m3u8file succeed; fullpath:%@, content:%@",fullpath,head);
        return  fullpath;
    } else {
        NSLog(@"create m3u8file failed:%@", error);
        return  nil;
    }
    return nil;
}

#pragma mark - 网络监测

- (void)pingReachability {
    if (!reachability)
    {
        BOOL ignoresAdHocWiFi = NO;
        struct sockaddr_in ipAddress;
        bzero(&ipAddress, sizeof(ipAddress));
        ipAddress.sin_len = sizeof(ipAddress);
        ipAddress.sin_family = AF_INET;
        ipAddress.sin_addr.s_addr = htonl(ignoresAdHocWiFi ? INADDR_ANY : IN_LINKLOCALNETNUM);
        
        /* Can also create zero addy
         struct sockaddr_in zeroAddress;
         bzero(&zeroAddress, sizeof(zeroAddress));
         zeroAddress.sin_len = sizeof(zeroAddress);
         zeroAddress.sin_family = AF_INET; */
        
        reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&ipAddress);
        CFRetain(reachability);
    }
    
    // Recover reachability flags
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(reachability, &connectionFlags);
    if (!didRetrieveFlags) printf("Error. Could not recover network reachability flags\n");
}

- (BOOL)networkAvailable {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self pingReachability];
    BOOL isReachable = ((connectionFlags & kSCNetworkFlagsReachable) != 0);
    BOOL needsConnection = ((connectionFlags & kSCNetworkFlagsConnectionRequired) != 0);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    return (isReachable && !needsConnection) ? YES : NO;
}

#pragma mark - dealloc

- (void)dealloc {
    NSLog(@"%@",@"释放了m3u8handler");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.loadSession removeObserver:self forKeyPath:@"nextTs"];
}

@end
