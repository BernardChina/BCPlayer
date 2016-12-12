//
//  BCVideoPlayer.h
//  
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "BCPlayer.h"
#import "BCPlayerDefine.h"
#import "BCPlayerDelegate.h"

typedef NS_ENUM(NSInteger, BCPlayerState) {
    BCPlayerStateBuffering = 1,    //正在缓存
    BCPlayerStatePlaying,          //正在播放
    BCPlayerStateStopped,          //播放结束
    BCPlayerStatePause,            //暂停播放
    BCPlayerStateFinish,           //播放完成
};

@interface BCVideoPlayer : NSObject

@property (nonatomic, readonly) BCPlayerState  state;                   //视频Player状态
@property (nonatomic, readonly) CGFloat        loadedProgress;          //缓冲的进度
@property (nonatomic, readonly) CGFloat        duration;                //视频总时间
@property (nonatomic, readonly) CGFloat        current;                 //当前播放时间
//@property (nonatomic, readonly) CGFloat        progress;                //播放进度0~1之间
@property (nonatomic, assign  ) BOOL           stopInBackground;        //是否在后台播放，默认YES
@property (nonatomic, weak) id<BCPlayerDelegate> delegate;

+ (instancetype)sharedInstance;

/**
 播放视频(本地或服务器),缓存文件url经过md5加密

 @param url 视频地址
 @param showView 显示的view
 @param superView 显示view的父view
 @param cacheType 播放缓存机制，不缓存，边播边缓存，先缓存再播放
 */
- (void)playWithUrl:(NSURL *)url
           showView:(UIView *)showView
       andSuperView:(UIView *)superView
          cacheType:(NBPlayerCacheType)cacheType;

/**
 *  指定到某一事件点开始播放
 *
 *  @param seconds 时间点
 */
- (void)seekToTime:(CGFloat)seconds;

/**
 * 恢复播放
 */
//- (void)resume;

/**
 *  暂停播放
 */
//- (void)pause;

/**
 *  停止播放
 */
- (void)stop;

/**
 *  全屏
 */
//- (void)fullScreen;

/**
 *  隐藏工具条
 */
//- (void)toolViewHidden;

/**
 *  显示工具条
 */
//- (void)showToolView;

/**
 *  半屏幕
 */
//- (void)halfScreen;

/**
 *  清除所有本地缓存视频文件
 */
+ (void)clearAllVideoCache;

/**
 *  计算所有视频缓存大小
 *
 *  @return 视频缓存大小
 */
+ (double)allVideoCacheSize;

/**
 *  清楚某个链接的缓存
 *
 *  @param url 链接地址
 */
+ (void)clearVideoCache:(NSString *)url;

@end
