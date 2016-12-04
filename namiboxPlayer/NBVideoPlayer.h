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

FOUNDATION_EXPORT NSString *const kNBPlayerStateChangedNotification;
FOUNDATION_EXPORT NSString *const kNBPlayerProgressChangedNotification;
FOUNDATION_EXPORT NSString *const kNBPlayerLoadProgressChangedNotification;

typedef NS_ENUM(NSInteger, NBPlayerState) {
    NBPlayerStateBuffering = 1,    //正在缓存
    NBPlayerStatePlaying,          //正在播放
    NBPlayerStateStopped,          //播放结束
    NBPlayerStatePause,            //暂停播放
    NBPlayerStateFinish,           //播放完成
};

@interface NBVideoPlayer : NSObject

@property (nonatomic, readonly) NBPlayerState  state;                   //视频Player状态
@property (nonatomic, readonly) CGFloat        loadedProgress;          //缓冲的进度
@property (nonatomic, readonly) CGFloat        duration;                //视频总时间
@property (nonatomic, readonly) CGFloat        current;                 //当前播放时间
@property (nonatomic, readonly) CGFloat        progress;                //播放进度0~1之间
@property (nonatomic, assign  ) BOOL           stopInBackground;        //是否在后台播放，默认YES

@property (nonatomic, assign  ) NSInteger playCount;                    //当前播放次数
@property (nonatomic, assign  ) NSInteger playRepatCount;               //重复播放次数

@property (nonatomic, copy    ) void(^playNextBlock)();                 //播放下一个block

+ (instancetype)sharedInstance;

/**
 *  播放服务器的视频，先判断本地是否有缓存文件，缓存文件名为连接的url经过md5加密后生成的字符串
 *
 *  @param url       视频地址
 *  @param showView  显示的View
 *  @param withCache 是否播放缓存的文件
 */
- (void)playWithUrl:(NSURL *)url
           showView:(UIView *)showView
       andSuperView:(UIView *)superView
          withCache:(BOOL)withCache;

/**
 *  指定到某一事件点开始播放
 *
 *  @param seconds 时间点
 */
//- (void)seekToTime:(CGFloat)seconds;

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
