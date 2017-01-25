//
//  NBPlayerDefine.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBPlayerDefine.h"
#import "NBPlayer.h"

NSString *saveCachePathForVideo(NSString *url) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSURL *playUrl = [components URL];
    NSString *key = [NSString stringWithFormat:@"%@%ld",[playUrl absoluteString],(long)currentCacheType];
    NSString *md5File = @"";
    if (isHLS) {
        md5File = [NSString stringWithFormat:@"%@.m3u8", [key stringToMD5]];
    } else {
        md5File = [NSString stringWithFormat:@"%@.mp4", [key stringToMD5]];
    }
    
    cacheVieoName = md5File;
    
    //这里自己写需要保存数据的路径
    NSString *document = [[NBPlayerEnvironment defaultEnvironment] cachePath];
    NSString *tempPath = [document stringByAppendingString:[NSString stringWithFormat:@"/%@",[key stringToMD5]]];
    
    BOOL isDir;
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:tempPath isDirectory:&isDir];
    if (!(isExist && isDir)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    cachePathForVideo = tempPath;
    
    NSString *cachePath =  [tempPath stringByAppendingPathComponent:md5File];
    
    return cachePath;
}

NSString *cachePathForVideo = @"";
NSString *cacheVieoName = @"";

NBPlayerCacheType currentCacheType = NBPlayerCacheTypeNoCache;
BOOL isHLS = NO;

NSString* const httpServerLocalUrl = @"http://127.0.0.1:12345/";

NSString *const kNBPlayerCurrentTimeChangedNofification = @"NBPlayerCurrentTimeChangedNofification";

double durationWithHLS = 0;
