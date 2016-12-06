//
//  NBPlayerDefine.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBPlayerDefine.h"
#import "NBPlayer.h"

NSString *cachePathForVideo(NSString *url) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSURL *playUrl = [components URL];
    NSString *md5File = [NSString stringWithFormat:@"%@.mp4", [[playUrl absoluteString] stringToMD5]];
    
    //这里自己写需要保存数据的路径
    NSString *document = [[NBPlayerEnvironment defaultEnvironment] cachePath];
    NSString *cachePath =  [document stringByAppendingPathComponent:md5File];
    return cachePath;
}

NSURL *getSchemeVideoURL(NSString *url) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    return [components URL];
}

NBPlayerCacheType currentCacheType = NBPlayerCacheTypeNoCache;
