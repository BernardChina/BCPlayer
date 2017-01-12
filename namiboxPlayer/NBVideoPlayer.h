//
//  NBVideoPlayer.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "NBPlayer.h"
#import "NBPlayerDefine.h"
#import "NBPlayerDelegate.h"
#import "NBPlayerView.h"

typedef NS_ENUM(NSInteger, NBPlayerState) {
    NBPlayerStateDefault,
    NBPlayerStateBuffering = 1,    //正在缓存
    NBPlayerStateWillPlay,         //将要播放，资源已经准备好了，但是palyer本身还没有开始播放
    NBPlayerStatePlaying,          //正在播放
    NBPlayerStateFailed,           //播放结束
    NBPlayerStatePause,            //暂停播放
    NBPlayerStateFinish,           //播放完成
};

@interface NBVideoPlayer : NSObject

@property (nonatomic, readonly) NBPlayerState  state;                   //视频Player状态
@property (nonatomic, readonly) NSURL *playUrl;
@property (nonatomic, readonly) CGFloat        loadedProgress;          //缓冲的进度
@property (nonatomic, readonly) CGFloat        duration;                //视频总时间
@property (nonatomic, readonly) double        current;                 //当前播放时间
//@property (nonatomic, readonly) CGFloat        progress;                //播放进度0~1之间
@property (nonatomic, strong) NBPlayerView  *playerView;
@property (nonatomic, assign  ) BOOL           stopInBackground;        //是否在后台播放，默认YES
@property (nonatomic, weak) id<NBPlayerDelegate> delegate;
@property (nonatomic, assign) BOOL isShowFullScreen;
@property (nonatomic, assign) BOOL autoPlay;    // 是否自动播放

//+ (instancetype)sharedInstance;

/**
 播放视频(本地或服务器),缓存文件url经过md5加密

 @param url 视频地址
 @param showView 显示的view
 @param cacheType 播放缓存机制，不缓存，边播边缓存，先缓存再播放
 */
- (void)playWithUrl:(NSURL *)url
           showView:(UIView *)showView
          cacheType:(NBPlayerCacheType)cacheType;

/**
 *  指定到某一事件点开始播放
 *
 *  @param seconds 时间点
 */
- (void)seekToTime:(CGFloat)seconds withAutoPlay:(BOOL)autoPlay;


/**
 设置静音模式

 @param isMute 是否静音
 */
- (void)makePalyerMute:(BOOL)isMute;

/**
 播放
 */
- (void)play;

/**
 * 恢复播放。在播放过程中，暂停了播放调用了pause，此时调用resume，可以恢复播放
 */
//- (void)resume;

/**
 *  暂停播放
 */
- (void)pause;

/**
 *  停止播放，并进行释放player
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

@end
