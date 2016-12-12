//
//  BCPlayerDefine.m
//  
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import "BCPlayerDefine.h"
#import "BCPlayer.h"
#import "BCPlayerEnvironment.h"

NSString *saveCachePathForVideo(NSString *url) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSURL *playUrl = [components URL];
    NSString *md5File = @"";
    if (currentCacheType == NBPlayerCacheTypePlayHLS) {
        md5File = [NSString stringWithFormat:@"%@.m3u8", [[playUrl absoluteString] stringToMD5]];
    } else {
        md5File = [NSString stringWithFormat:@"%@.mp4", [[playUrl absoluteString] stringToMD5]];
    }
    
    cacheVieoName = md5File;
    
    //这里自己写需要保存数据的路径
    NSString *document = [[BCPlayerEnvironment defaultEnvironment] cachePath];
    NSString *tempPath = [document stringByAppendingString:[NSString stringWithFormat:@"/%@",[[playUrl absoluteString] stringToMD5]]];
    
    BOOL isDir;
    [[NSFileManager defaultManager] fileExistsAtPath:tempPath isDirectory:&isDir];
    if (!isDir) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    cachePathForVideo = tempPath;
    
    NSString *cachePath =  [tempPath stringByAppendingPathComponent:md5File];
    
    return cachePath;
}

NSString *cachePathForVideo = @"";
NSString *cacheVieoName = @"";

NSURL *getSchemeVideoURL(NSString *url) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    return [components URL];
}

NBPlayerCacheType currentCacheType = NBPlayerCacheTypeNoCache;

NSString *const kNBPlayerStateChangedNotification    = @"NBPlayerStateChangedNotification";
NSString *const kNBPlayerProgressChangedNotification = @"NBPlayerProgressChangedNotification";
NSString *const kNBPlayerLoadProgressChangedNotification = @"NBPlayerLoadProgressChangedNotification";

NSString* const httpServerLocalUrl = @"http://127.0.0.1:12345/";
