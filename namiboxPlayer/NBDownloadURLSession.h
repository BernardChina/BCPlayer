//
//  NBDownloadURLSession.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

@class M3U8SegmentInfo;
@interface NBDownloadURLSession : NSObject

/**
 监听下载进度
 */
@property (nonatomic, assign) double downloadProgress;

/**
 监听此值，当为true的时候，开始播放
 */
@property (nonatomic, assign) BOOL startPlay;

/**
 下一个ts，监听这个值，当此值变化的时候，开始缓存这个ts
 */
@property (nonatomic, assign) NSInteger nextTs;

/**
 ts文件list
 */
@property (nonatomic, strong) NSArray *hlsUrls;

/**
 但前播放的ts
 */
@property (nonatomic, assign) NSInteger currentIndex;

- (void)cancel;

- (void)addDownloadTask:(NSString *)playUrl;

@end
