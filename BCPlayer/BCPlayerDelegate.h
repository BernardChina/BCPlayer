//
//  BCPlayerDelegate.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/6.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BCVideoPlayer.h"

@class BCVideoPlayer;
@protocol BCPlayerDelegate <NSObject>

/**
 播放完成调用此方法

 @param player 当前的player
 @param error 如果播放过程中有错误，回调返回error
 */
- (void)BCVideoPlayer:(BCVideoPlayer *)player didCompleteWithError:(NSError *)error;


/**
 返回播放进度

 @param player 当前的player
 @param progress 播放进度
 */
- (void)BCVideoPlayer:(BCVideoPlayer *)player withProgress:(double)progress currentTime:(double)current totalTime:(double)totalTime;

@end
