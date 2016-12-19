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

@interface NBPlayerM3U8Handler()

@property (nonatomic, strong) NSMutableArray *segments;

@end

@implementation M3U8SegmentInfo

@end

@implementation NBPlayerM3U8Handler

- (instancetype)init {
    if (self == [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTimeChanged:) name:kNBPlayerCurrentTimeChangedNofification object:nil];
        
    }
    return self;
}

- (void)praseUrl:(NSString *)urlstr {
    NSURL *url = [[NSURL alloc] initWithString:urlstr];
    NSError *error = nil;
    NSStringEncoding encoding;
    /** 获取到返回的响应字符串，其中包含该视频流的信息 */
    NSString *data = [[NSString alloc] initWithContentsOfURL:url
                                                usedEncoding:&encoding
                                                       error:&error];
    
    if (error) {
        if (self.praseFailed) {
            self.praseFailed(error);
        }
    }
    
    if(data == nil) {
        if (self.praseFailed) {
            self.praseFailed([NSError errorWithDomain:@"服务器返回数据为空" code:0 userInfo:nil]);
        }
        return;
    }
    
    if (![data containsString:@"#EXTINF:"]) {
        if (self.praseFailed) {
            self.praseFailed([NSError errorWithDomain:@"服务器返回数据错误" code:0 userInfo:nil]);
        }
        return;
    }
    self.segments = [[NSMutableArray alloc] init];
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    NSString* remainData =data;
    NSArray *array = [remainData componentsSeparatedByString:@"#EXTINF:"];
    NSString *baseUrl = [@"http://" stringByAppendingString:url.host];
    
    [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx != 0) {
            NSArray *temp = [obj componentsSeparatedByString:@","];
            M3U8SegmentInfo * segment = [[M3U8SegmentInfo alloc]init];
            segment.duration = [temp[0] intValue];
            segment.locationUrl = [self removeSpaceAndNewlineAndOtherFlag:temp[1]];
            if (![segment.locationUrl hasPrefix:@"http"]) {
                
                segment.locationUrl = [baseUrl stringByAppendingString:segment.locationUrl];
            }
            [urls addObject:[NSURL URLWithString:segment.locationUrl]];
            
            [self.segments addObject:segment];
        }
    }];
    
    self.loadSession.hlsUrls = urls;
    
    [self.loadSession addObserver:self forKeyPath:@"nextTs" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
    
    NSError *errord = nil;
    NSArray *fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachePathForVideo error:&errord];
    
    // 说明没有下载完成，只是下载了一部分
    if (fileList.count - 1 < self.segments.count) {
        self.loadSession.startPlay =  YES;
        return;
    }
    
    [self createLocalM3U8file];
    
    if (self.segments.firstObject) {
        M3U8SegmentInfo * segment = self.segments.firstObject;
        [self.loadSession addDownloadTask:segment.locationUrl];
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
            M3U8SegmentInfo * segment = [self.segments objectAtIndex:nextTs];
            if (segment) {
                [self.loadSession addDownloadTask:segment.locationUrl];
            }
            return;
        }
    }
}

- (void)currentTimeChanged:(NSNotification *)notification {
    
    if (notification) {
        NSDictionary *dic = notification.userInfo;
        if (!dic) {
            return;
        }
        NSInteger current = [dic[@"currentTime"] integerValue];
        __block NSInteger currentIndex = 0;//当前播放到哪一个ts
        __block NSInteger temp = 0;
        [self.segments enumerateObjectsUsingBlock:^(M3U8SegmentInfo *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            temp += obj.duration;
            if (current <= temp) {
                currentIndex = idx;
                *stop = YES;
                return ;
            }
        }];
        self.loadSession.currentIndex = currentIndex;
        NSLog(@"当钱播放的index：%ld",(long)currentIndex);
        
        if (currentIndex == self.segments.count - 1) {
            if (self.playFinished) {
                self.playFinished();
            }
        }
    }
}

-(NSString*)createLocalM3U8file {
    
    NSString *fullpath = [cachePathForVideo stringByAppendingPathComponent:cacheVieoName];
    
    //    NSFileManager *fileManager = [NSFileManager defaultManager];
    //    if (![fileManager fileExistsAtPath:fullpath]) {
    //        return nil;
    //    }
    
    //创建文件头部
    __block NSString* head = @"#EXTM3U\n#EXT-X-TARGETDURATION:30\n#EXT-X-VERSION:2\n#EXT-X-DISCONTINUITY\n";
    
    [self.segments enumerateObjectsUsingBlock:^(M3U8SegmentInfo *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *localUrl = [httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%ld.ts",(long)idx]];
        NSString* length = [NSString stringWithFormat:@"#EXTINF:%ld,\n",(long)obj.duration];
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

- (void)dealloc {
    NSLog(@"%@",@"释放了m3u8handler");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.loadSession removeObserver:self forKeyPath:@"nextTs"];
}

@end
