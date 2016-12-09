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

@interface NBPlayerM3U8Handler()

@end

@implementation M3U8SegmentInfo


@end

@implementation NBPlayerM3U8Handler

- (void)praseUrl:(NSString *)urlstr {
    NSURL *url = [[NSURL alloc] initWithString:urlstr];
//    NSURL *baseUrl = [url URLByDeletingLastPathComponent];
    NSError *error = nil;
    NSStringEncoding encoding;
    /** 获取到返回的响应字符串，其中包含该视频流的信息 */
    NSString *data = [[NSString alloc] initWithContentsOfURL:url
                                                usedEncoding:&encoding
                                                       error:&error];
    
    if(data == nil) {
//        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(praseM3U8Failed:error:)])
//        {
//            [self.delegate praseM3U8Failed:self error:[NSError errorWithDomain:@"服务器返回数据为空" code:0 userInfo:nil]];
//        }
        return;
    }
    
    if (![data containsString:@"#EXTINF:"]) {
//        if(self.delegate != nil && [self.delegate respondsToSelector:@selector(praseM3U8Failed:error:)])
//        {
//            [self.delegate praseM3U8Failed:self error:[NSError errorWithDomain:@"服务器返回数据错误" code:0 userInfo:nil]];
//        }
        return;
    }
    NSMutableArray *segments = [[NSMutableArray alloc] init];
    NSString* remainData =data;
    
    NSArray *array = [remainData componentsSeparatedByString:@"#EXTINF:"];
    
    [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx != 0) {
            NSArray *temp = [obj componentsSeparatedByString:@","];
            M3U8SegmentInfo * segment = [[M3U8SegmentInfo alloc]init];
            segment.duration = [temp[0] intValue];
            segment.locationUrl = [self removeSpaceAndNewlineAndOtherFlag:temp[1]];
            self.loadSession.segmentInfo = segment;
            [self.loadSession addDownloadTask:segment.locationUrl];
            
            [segments addObject:segment];
        }
    }];
}

- (NSString *)removeSpaceAndNewlineAndOtherFlag:(NSString *)str {
    NSString *temp = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"," withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    return temp;
}

@end
