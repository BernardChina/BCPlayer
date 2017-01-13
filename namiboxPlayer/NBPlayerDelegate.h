//
//  NBPlayerDelegate.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/6.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBVideoPlayer.h"

@class NBVideoPlayer;
@protocol NBPlayerDelegate <NSObject>
@optional
/**
 播放完成调用此方法

 @param player 当前的player
 @param error 如果播放过程中有错误，回调返回error
 */
- (void)NBVideoPlayer:(NBVideoPlayer *)player didCompleteWithError:(NSError *)error;


/**
 返回播放进度

 @param player 当前的player
 @param progress 播放进度
 */
- (void)NBVideoPlayer:(NBVideoPlayer *)player withProgress:(double)progress currentTime:(double)current totalTime:(double)totalTime;

/**
 缓存是否完成成功
 
 @param player 当前的palyer
 @param success 是否成功
 */
- (void)NBVideoPlayer:(NBVideoPlayer *)player withCacheSuccess:(BOOL)success;

@end
