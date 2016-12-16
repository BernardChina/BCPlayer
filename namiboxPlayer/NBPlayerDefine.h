//
//  NBPlayerDefine.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NBPlayerCacheType) {
    NBPlayerCacheTypeNoCache,       // 不缓存，直接播放
    NBPlayerCacheTypePlayWithCache, // 边播放边缓存
    NBPlayerCacheTypePlayAfterCache, // 先缓存，再播放
    NBPlayerCacheTypePlayHLS    // 支持hls
};

extern NSString *saveCachePathForVideo(NSString *url);
extern NSString *cachePathForVideo;
// 加密后的视频名称
extern NSString *cacheVieoName;
extern NSURL *getSchemeVideoURL(NSString *url);
extern NBPlayerCacheType currentCacheType;

// 暴漏出来的通知
FOUNDATION_EXPORT NSString *const kNBPlayerStateChangedNotification;
FOUNDATION_EXPORT NSString *const kNBPlayerProgressChangedNotification;
FOUNDATION_EXPORT NSString *const kNBPlayerLoadProgressChangedNotification;

static void* const DownloadKVOContext = (void *)&DownloadKVOContext;

extern NSString* const httpServerLocalUrl;

// 播放器当前播放时间改变通知
FOUNDATION_EXPORT NSString *const kNBPlayerCurrentTimeChangedNofification;

