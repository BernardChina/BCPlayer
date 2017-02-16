//
//  NBVideoPlayer.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBVideoPlayer.h"
#import "NBLoaderURLSession.h"
#import "NBPlayerView.h"
#import "NBTimeSheetView.h"
#import "NBLightView.h"
#import "NSString+NB.h"
#import "NBPlayer.h"
#import "NBPlayerDefine.h"
#import "NBDownloadURLSession.h"
#import "NBPlayerDefine.h"
#import "NBPlayerM3U8Handler.h"
#import "HTTPServer.h"

#import <AVKit/AVKit.h>

#define LeastMoveDistance 15
#define TotalScreenTime 90

static NSString *const NBVideoPlayerItemStatusKeyPath = @"status";
static NSString *const NBVideoPlayerItemLoadedTimeRangesKeyPath = @"loadedTimeRanges";
static NSString *const NBVideoPlayerItemPlaybackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const NBVideoPlayerItemPresentationSizeKeyPath = @"presentationSize";

typedef enum : NSUInteger {
    NBPlayerControlTypeProgress,
    NBPlayerControlTypeVoice,
    NBPlayerControlTypeLight,
    NBPlayerControlTypeNone = 999,
} NBPlayerControlType;

@interface NBVideoPlayer()<NBLoaderURLSessionDelegate, UIGestureRecognizerDelegate>{
    //用来控制上下菜单view隐藏的timer
    NSTimer * _hiddenTimer;
    UIInterfaceOrientation _currentOrientation;
    
    //用来判断手势是否移动过
    BOOL _hasMoved;
    //判断是否已经判断出手势划的方向
    BOOL _controlJudge;
    //触摸开始触碰到的点
    CGPoint _touchBeginPoint;
    //记录触摸开始时的视频播放的时间
    float _touchBeginValue;
    //记录触摸开始亮度
    float _touchBeginLightValue;
    //记录触摸开始的音量
    float _touchBeginVoiceValue;
    
    //网络播放地址
    NSURL *_playUrl;
    NBPlayerCacheType _cacheType;
}

@property (nonatomic, strong)HTTPServer * httpServer;

@property (nonatomic, assign) NBPlayerState state;
@property (nonatomic, assign) CGFloat        loadedProgress;
@property (nonatomic, assign) double        duration;
@property (nonatomic, assign) double        current;

@property (nonatomic, strong) AVURLAsset     *videoURLAsset;
@property (nonatomic, strong) AVAsset        *videoAsset;
@property (nonatomic, strong) AVPlayer       *player;
@property (nonatomic, strong) AVPlayerItem   *currentPlayerItem;
@property (nonatomic, strong) NSObject       *playbackTimeObserver;
@property (nonatomic, assign) BOOL           isPauseByUser;           //是否被用户暂停

@property (nonatomic, weak  ) UIView         *showView;
@property (nonatomic, assign) CGRect         showViewRect;            //视频展示ViewRect
@property (nonatomic, strong) UIView         *touchView;              //事件响应View

@property (nonatomic, strong) UIView         *statusBarBgView;        //全屏状态栏的背景view
@property (nonatomic, strong) UIView         *toolView;
@property (nonatomic, strong) UILabel        *currentTimeLbl;         //当前播放时间
@property (nonatomic, strong) UILabel        *totalTimeLbl;           //总共播放时间
@property (nonatomic, strong) UIProgressView *videoProgressView;      //缓冲进度条
@property (nonatomic, strong) UIProgressView *bottomProgress;
@property (nonatomic, strong) UISlider       *playSlider;             //滑竿
@property (nonatomic, strong) UIButton       *stopButton;             //播放暂停按钮
@property (nonatomic, strong) UIButton       *screenButton;           //全屏按钮
@property (nonatomic, strong) UIButton       *repeatBtn;              //重播按钮
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIView         *netWorkPoorView;        //网络不佳view
@property (nonatomic, strong) UILabel        *errorLabel;           //错误文案
@property (nonatomic, assign) BOOL           isFullScreen;
@property (nonatomic, assign) BOOL           canFullScreen;
@property (nonatomic, strong) UIActivityIndicatorView *actIndicator;  //加载视频时的旋转菊花
@property (nonatomic, strong) UILabel *actIndicatorLabel; // 菊花文案

@property (nonatomic, strong) MPVolumeView   *volumeView;             //音量控制控件
@property (nonatomic, strong) UISlider       *volumeSlider;           //用这个来控制音量

@property (nonatomic, strong) NBLoaderURLSession *resouerLoader;      //缓存session
@property (nonatomic, strong) NBDownloadURLSession *downloadSession;  //下载session

@property (nonatomic, assign) NBPlayerControlType controlType;       //当前手势是在控制进度、声音还是亮度
@property (nonatomic, strong) NBTimeSheetView *timeSheetView;        //左右滑动时间View
@property (nonatomic, strong) NSString *cachePath;
@property (nonatomic, strong) NBPlayerM3U8Handler *m3u8Handler;
@property (nonatomic, assign) BOOL playFinished;
@property (nonatomic, assign) BOOL downloadFailed;
@property (nonatomic, assign) BOOL requestFailed;
@property (nonatomic, assign) BOOL canTapTouchView;
@property (nonatomic, assign) BOOL isRepeated;

@property (nonatomic, assign) NSInteger nextTs; // 只有解析失败的时候，才会记录

@end

@implementation NBVideoPlayer

//+ (instancetype)sharedInstance {
//    
//    static dispatch_once_t onceToken;
//    static NBVideoPlayer *instance;
//    
//    dispatch_once(&onceToken, ^{
//        instance = [[self alloc]init];
//    });
//    return instance;
//}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPauseByUser = YES;
        _loadedProgress = 0;
        _duration = 0;
        _current  = 0;
        _state = NBPlayerStateDefault;
        _stopInBackground = YES;
        _isFullScreen = NO;
        _canFullScreen = YES;
        _autoPlay = YES;
        
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                _currentOrientation = UIInterfaceOrientationPortrait;
                break;
            case UIDeviceOrientationLandscapeLeft:
                _currentOrientation = UIInterfaceOrientationLandscapeLeft;
                break;
            case UIDeviceOrientationLandscapeRight:
                _currentOrientation = UIInterfaceOrientationLandscapeRight;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                _currentOrientation = UIInterfaceOrientationPortraitUpsideDown;
                break;
            default:
                break;
        }
        [NBLightView sharedInstance];
    }
    return self;
}

// 假如不缓存 或者 边播边缓存
- (void)playWithVideoUrl:(NSURL *)url showView:(UIView *)showView {
    
    if ([url.scheme isEqualToString:@"https"] || [url.scheme isEqualToString:@"http"]) {
        
        self.resouerLoader          = [[NBLoaderURLSession alloc] init];
        self.resouerLoader.playCachePath = self.cachePath;
        self.resouerLoader.loaderURLSessionDelegate = self;
        
        NSURL *playUrl              = [self.resouerLoader getSchemeVideoURL:url];
        self.videoURLAsset          = [AVURLAsset URLAssetWithURL:playUrl options:nil];
        [_videoURLAsset.resourceLoader setDelegate:self.resouerLoader queue:dispatch_get_main_queue()];
        self.currentPlayerItem      = [AVPlayerItem playerItemWithAsset:_videoURLAsset];
    }
    
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    
    [(AVPlayerLayer *)self.playerView.layer setPlayer:self.player];
    
    [self commonPlayerObserver];
    
    // 边播边缓存或者不缓存，此时应该是buffering状态
    self.state = NBPlayerStateBuffering;
    
}

// 播放本地视频
- (void)playWithLocalUrl:(NSURL *)url {
//    if (!self.autoPlay) {
//        self.playBtn.hidden = NO;
//        return;
//    }
    [self removeCommonPlayerObserver];
    
    if (isHLS) {
        [self openHttpServer];
    }
    self.videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:_videoAsset];
    
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    
    [(AVPlayerLayer *)self.playerView.layer setPlayer:self.player];
    
    [self commonPlayerObserver];
    
    self.state = NBPlayerStateWillPlay;
}

// 缓存后播放
- (void)playAfterCacheWithVideoUrl:(NSURL *)url {
    
    NSString *str = [url absoluteString];
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        self.downloadSession = [[NBDownloadURLSession alloc] init];
        [self.downloadSession addDownloadTask:str withIndex:0];
        
        [self.downloadSession addObserver:self forKeyPath:@"downloadProgress" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        [self.downloadSession addObserver:self forKeyPath:@"startPlay" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        
        __weak __typeof(self)weakSelf = self;
        
        self.downloadSession.downloadFailed = ^(NSError *error, NSURLSessionTask *task, NSInteger nextTs){
            if (error) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                strongSelf.downloadFailed = YES;
                strongSelf.nextTs= nextTs;
                if (strongSelf.state == NBPlayerStateDefault) {
                    [strongSelf showNetWorkPoorView];
                }
            }
        };
    }
    
}

- (void)playWithNoCache:(NSURL *)url {
    [self removeCommonPlayerObserver];
    
    self.videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:_videoAsset];
    
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    
    [(AVPlayerLayer *)self.playerView.layer setPlayer:self.player];
    
    [self commonPlayerObserver];
}

// 支持hls
- (void)playHLSWithUrl:(NSURL *)url {
    // 不缓存
    if (currentCacheType == NBPlayerCacheTypeNoCache) {
        
        [self playWithNoCache:url];
        
        return;
    }
    
    self.playFinished = NO;
    NSString *str = [url absoluteString];
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        self.m3u8Handler = [[NBPlayerM3U8Handler alloc] init];
        self.downloadSession = [[NBDownloadURLSession alloc] init];
        self.m3u8Handler.loadSession = self.downloadSession;
        [self.downloadSession addObserver:self forKeyPath:@"downloadProgress" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        [self.downloadSession addObserver:self forKeyPath:@"startPlay" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        
        __weak __typeof(self)weakSelf = self;
        
        self.downloadSession.downloadFailed = ^(NSError *error, NSURLSessionTask *task, NSInteger nextTs){
            if (error) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                strongSelf.downloadFailed = YES;
                strongSelf.nextTs= nextTs;
                if (strongSelf.state == NBPlayerStateDefault) {
                    [strongSelf showNetWorkPoorView];
                }
            }
        };
        
        weakSelf.m3u8Handler.praseFailed = ^(NSError *err, NSInteger nextTs){
            // 解析失败
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            
            switch (err.code) {
                case 3000:
                    weakSelf.errorLabel.text = @"网络不可用，请点击屏幕重试";
                    break;
                case 3001:
                    weakSelf.errorLabel.text = @"服务器返回数据为空, 请点击屏幕重试";
                    break;
                case 3002:
                    weakSelf.errorLabel.text = @"服务器返回数据错误, 请点击屏幕重试";
                    break;
                    
                default:
                    break;
            }
            
            strongSelf.nextTs= nextTs;
            if (strongSelf.state == NBPlayerStateDefault) {
                [strongSelf showNetWorkPoorView];
            }
            if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(NBVideoPlayer:didCompleteWithError:)]) {
                [strongSelf.delegate NBVideoPlayer:strongSelf didCompleteWithError:err];
            }
            
        };
        weakSelf.m3u8Handler.playFinished = ^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf.playFinished = YES;
        };
        
        [self.m3u8Handler praseUrl:url.absoluteString];
    }
}
- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView cacheType:(NBPlayerCacheType)cacheType {
    if ([_playUrl isEqual:url] && self.player && !self.isRepeated) {
        return;
    }
    _playUrl = url;
    _cacheType = cacheType;
    
    if ([url.lastPathComponent hasSuffix:@".m3u8"]) {
        isHLS = YES;
    } else {
        isHLS = NO;
    }
    
    currentCacheType = cacheType;
    
    self.cachePath = saveCachePathForVideo(url.absoluteString);
    
    [self releasePlayer];
    
    self.isPauseByUser = NO;
    self.loadedProgress = 0;
    self.canTapTouchView = NO;
    self.duration = 0;
    self.current  = 0;
    
    _showView = showView;
    _showViewRect = _playerView.frame;
    _playerView.backgroundColor = [UIColor blackColor];
    
    [self setVideoToolView];
    
    [self toolViewHidden];
    
    // 支持hls
    if (isHLS) {
        [self playHLSWithUrl:url];
        return;
    }
    
    // 如果是本地文件url
    if ([url.scheme isEqualToString:@"file"]) {
        [self playWithLocalUrl:url];
        return;
    }
    
    // 假如有缓存文件，首先播放缓存文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
        
        [self playWithLocalUrl:localURL];
        return;
    }
    
    // 假如不缓存 或者 边播边缓存
    if (cacheType == NBPlayerCacheTypeNoCache || cacheType == NBPlayerCacheTypePlayWithCache) {
        [self playWithVideoUrl:url showView:showView];
    }
    
    // 缓存后再播放
    if (cacheType == NBPlayerCacheTypePlayAfterCache) {
        [self playAfterCacheWithVideoUrl:url];
    }
    
}

- (void)fullScreen {
    //如果全屏下
    if (_isFullScreen) {
        [self toOrientation:UIInterfaceOrientationPortrait];
    }else{
        [self toOrientation:UIInterfaceOrientationLandscapeRight];
    }
    [self showToolView];
}

- (void)halfScreen {
    
}

+ (void)clearVideoCache:(NSString *)url {
    
}

#pragma mark - observer

- (void)appDidEnterBackground {
    if (self.stopInBackground) {
        NSLog(@"当前状态appDidEnterBackground：%ld",(long)self.state);
        if (self.state == NBPlayerStatePlaying) {
            NSLog(@"appDidEnterBackgroundappDidEnterBackground");
            [self resumeOrPause];
            self.isPauseByUser = NO;
        }
    }
}
- (void)appDidEnterPlayGround {
    NSLog(@"当前状态appDidEnterPlayGround：%ld",(long)self.state);
    if (self.state == NBPlayerStateFinish) {
        return;
    }
    if (self.state == NBPlayerStatePlaying || !self.isPauseByUser) {
        [self resumeOrPause];
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    // 播放结束后，调用此通知，可以通过这个方法实现循环播放或者播放下个视频
    /*
     当播放结束后，播放头移动到playerItem的末尾，如果此时调用play方法是没有效果的，应该先把播放头移到player item起始位置。如果需要实现循环播放的功能，可以监听通知AVPlayerItemDidPlayToEndTimeNotification，当收到这个通知的时候，调用seekToTime：把播放头移动到起始位置[player seekToTime:kCMTimeZero];
     */
    //重新播放
    
    NSLog(@"%@",@"playerItemDidPlayToEnd");
    
    if (isHLS && !self.playFinished && currentCacheType == NBPlayerCacheTypePlayWithCache) {
        [self localUrlPlayer];
        
        [self seekToTime:_current completionHandler:nil];
        return;
    }
    
//    self.repeatBtn.hidden = NO;
    self.isRepeated = YES;
    self.playBtn.hidden = NO;
    [self toolViewHidden];
    self.state = NBPlayerStateFinish;
    self.isPauseByUser = NO;
    [self.stopButton setSelected:YES];
    
    [self.resouerLoader.task clearData];
    
    [self.bottomProgress setProgress:0];
    [self updateVideoSlider:0];
    [self.videoProgressView setProgress:0];
    
    // 播放结束
    if (self.delegate && [self.delegate respondsToSelector:@selector(NBVideoPlayer:didCompleteWithError:)]) {
        [self.delegate NBVideoPlayer:self didCompleteWithError:nil];
    }
    
}

//在监听播放器状态中处理比较准确，播放停止了，有可能是网络原因
- (void)playerItemPlaybackStalled:(NSNotification *)notification {
    // 这里网络不好的时候，就会进入，不做处理，会在playbackBufferEmpty里面缓存之后重新播放
    NSLog(@"buffing----buffing");
    [self.actIndicator startAnimating];
    self.actIndicator.hidden = NO;
    
    if (self.downloadFailed) {
        [self.player pause];
        
        self.state = NBPlayerStateFailed;
        [self showNetWorkPoorView];
        return;
    }
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    // 下载context
    if (context == DownloadKVOContext) {
        if ([object isEqual:self.downloadSession] && [keyPath isEqualToString:@"downloadProgress"]) {
            // 更改进度
            [self.videoProgressView setProgress:[[change objectForKey:NSKeyValueChangeNewKey] floatValue] animated:YES];
            self.loadedProgress = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            
            // 这个应该没有必要
            if (self.state != NBPlayerStatePlaying) {
                [self.actIndicator startAnimating];
                self.actIndicator.hidden = NO;
                self.actIndicatorLabel.text = [NSString stringWithFormat:@"缓存进度：%d%%",(int)(self.loadedProgress*100)];
            }
            
            return;
        }
        if ([object isEqual:self.downloadSession] && [keyPath isEqualToString:@"startPlay"]) {
            // 开始播放
            
            [self.actIndicator stopAnimating];
            self.actIndicator.hidden = YES;
            
            if (self.autoPlay) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
                    NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
                    if (isHLS) {
                        localURL = [NSURL URLWithString:[httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%@",cacheVieoName]]];
                    }
                    [self playWithLocalUrl:localURL];
                    if (isHLS && self.player.currentItem.status != AVPlayerStatusReadyToPlay) {
                        [self seekToTime:_current completionHandler:nil];
                    }
                }
                
                return;
            }
            
            // 用户设置不是自动播放，应该显示播放按钮
            self.state = NBPlayerStateDefault;
            self.playBtn.hidden = NO;
            
            return;
        }
    }
    
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([NBVideoPlayerItemStatusKeyPath isEqualToString:keyPath]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            NSLog(@"AVPlayerStatusReadyToPlay");
            
            [self showToolView];
            
            [self monitoringPlayback:playerItem];// 给播放器添加计时器
            
            self.canTapTouchView = YES;
            
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            [self stop];
            
            self.errorLabel.text = @"播放失败, 请点击屏幕重试";
            [self showNetWorkPoorView];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(NBVideoPlayer:didCompleteWithError:)]) {
                [self.delegate NBVideoPlayer:self didCompleteWithError:[NSError errorWithDomain:@"播放失败" code:0 userInfo:nil]];
            }
        }
        
    } else if ([NBVideoPlayerItemLoadedTimeRangesKeyPath isEqualToString:keyPath]) {
        //监听播放器的下载进度
        NSLog(@"%@",@"监听播放器的下载进度");
        [self calculateDownloadProgress:playerItem];
        
    } else if ([NBVideoPlayerItemPlaybackBufferEmptyKeyPath isEqualToString:keyPath]) {
        //监听播放器在缓冲数据的状态
        //指示播放是否已占用所有缓冲媒体，并且播放将停止或结束
        
        if (playerItem.isPlaybackBufferEmpty) {
            NSLog(@"%@",@"NBVideoPlayerItemPlaybackBufferEmptyKeyPath");
            self.state = NBPlayerStateBuffering;
            
            [self bufferingSomeSecond];
        }
    } else if ([NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath isEqualToString:keyPath]) {
         //playbackLikelyToKeepUp. 指示项目是否可能无阻塞地播放。;
        
        if (playerItem.isPlaybackLikelyToKeepUp) {
            NSLog(@"NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath");
            [self.actIndicator stopAnimating];
            self.actIndicator.hidden = YES;
            
            if (self.autoPlay && self.state != NBPlayerStatePause && self.state != NBPlayerStateFinish) {
                [self.player play];
                self.state = NBPlayerStatePlaying;
            } else {
                self.playBtn.hidden = NO;
            }
        }
    } else if ([NBVideoPlayerItemPresentationSizeKeyPath isEqualToString:keyPath]) {
        CGSize size = self.currentPlayerItem.presentationSize;
        static float staticHeight = 0;
        staticHeight = size.height/size.width * kScreenWidth;
        NSLog(@"%f", staticHeight);
        
        //用来监测屏幕旋转
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        _canFullScreen = YES;
    } else if([keyPath isEqualToString:@"rate"]) {
//        NSLog(@"当前rate：%f",self.player.rate);
        if (self.player.rate != 0) {
            NSLog(@"正在playing");
//            self.canTapTouchView = YES;
        } else {
            NSLog(@"还不能");
        }
    }
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    NSLog(@"添加了monitoringPlayback");
    // playerItem.duration. 表示项目媒体的持续时间
    self.duration = (double)playerItem.duration.value / (double)playerItem.duration.timescale; //视频总时间
    if (isHLS && currentCacheType == NBPlayerCacheTypePlayWithCache) {
        self.duration = durationWithHLS;
    }
    
    [self updateTotolTime:self.duration];
    [self setPlaySliderValue:self.duration];
    
    __weak __typeof(self)weakSelf = self;
    // addPeriodicTimeObserverForInterval. 请求在回放期间周期性调用给定块以报告改变时间
    
    weakSelf.playbackTimeObserver = [weakSelf.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        
        __strong __typeof(self)strongSelf = weakSelf;
        
        if (![playerItem isEqual:strongSelf.currentPlayerItem]) {
            return ;
        }
        
        // playerItem.currentTime. 返回项目的当前时间
        double current = (double)playerItem.currentTime.value / (double)playerItem.currentTime.timescale;
        _current = current;
        
        // 通知外面接受到播放信息
        if (self.delegate && [self.delegate respondsToSelector:@selector(NBVideoPlayer:withProgress:currentTime:totalTime:)]) {
            [weakSelf.delegate NBVideoPlayer:weakSelf withProgress:0 currentTime:current totalTime:weakSelf.duration];
        }
        
        if (!strongSelf.playSlider.isSelected) {
            [strongSelf updateCurrentTime:current];
            [strongSelf updateVideoSlider:current];
        }
        
        // 当只有hls格式视频，并且边播边缓存的时候，才发送通知
        if (isHLS ) {
            NSLog(@"playerItem：%@",playerItem);
            NSLog(@"时间还会变吗：%f",current);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerCurrentTimeChangedNofification object:nil userInfo:@{@"currentTime":@(current)}];
        }
        
//        if (strongSelf.isPauseByUser == NO) {
//            NSLog(@"ddddddddddddddd");
//            strongSelf.state = NBPlayerStatePlaying;
//        }
        
        // 不相等的时候才更新，并发通知，否则seek时会继续跳动
        if (strongSelf.current != current) {
            strongSelf.current = current;
            if (strongSelf.current > strongSelf.duration) {
                strongSelf.duration = strongSelf.current;
            }
        }
        
    }];
    
}

- (void)unmonitoringPlayback {
    if (self.playbackTimeObserver != nil) {
        [self.player removeTimeObserver:self.playbackTimeObserver];
        self.playbackTimeObserver = nil;
    }
}

// 计算缓存进度
- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem {
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    if (isHLS && currentCacheType == NBPlayerCacheTypePlayWithCache) {
        self.duration = durationWithHLS;
    }
    
    self.loadedProgress = timeInterval / totalDuration;
    [self.videoProgressView setProgress:timeInterval / totalDuration animated:NO];
}

- (void)bufferingSomeSecond {
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (self.isPauseByUser) {
            isBuffering = NO;
            return;
        }
        
        [self.player play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        isBuffering = NO;
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            [self bufferingSomeSecond];
            if (isHLS && currentCacheType == NBPlayerCacheTypePlayWithCache && !self.playFinished) {
                [self localUrlPlayer];
                [self seekToTime:_current completionHandler:nil];
            } else {
                if (self.downloadFailed) {
                    [self.player pause];
                    [self showNetWorkPoorView];
                }
            }
        }
    });
}

- (void)setLoadedProgress:(CGFloat)loadedProgress {
    if (_loadedProgress == loadedProgress) {
        return;
    }
    
    if (loadedProgress >= 1 && self.delegate && [self.delegate respondsToSelector:@selector(NBVideoPlayer:withCacheSuccess:)]) {
        [self.delegate NBVideoPlayer:self withCacheSuccess:YES];
    }
    
    _loadedProgress = loadedProgress;
}

- (void)setState:(NBPlayerState)state {
    if (state == NBPlayerStatePause || state == NBPlayerStateFinish) {
        self.playBtn.hidden = NO;
    } else {
        self.playBtn.hidden = YES;
    }
    if (state != NBPlayerStateBuffering) {
        [self.actIndicator stopAnimating];
        self.actIndicator.hidden = YES;
    } else {
        [self.actIndicator startAnimating];
        self.actIndicator.hidden = NO;
    }
    
    if (_state == state) {
        return;
    }
    
    _state = state;
    
}

#pragma mark - 界面控件初始化

- (NBPlayerView *)playerView {
    if (!_playerView) {
        _playerView = [[NBPlayerView alloc]init];
    }
    return _playerView;
}

- (UIView *)statusBarBgView {
    if (!_statusBarBgView) {
        _statusBarBgView = [[UIView alloc]init];
        _statusBarBgView.backgroundColor = [UIColor blackColor];
        _statusBarBgView.hidden = YES;
    }
    return _statusBarBgView;
}

- (UIView *)toolView {
    
    if (!_toolView) {
        _toolView = [[UIView alloc]init];
        _toolView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        _toolView.hidden = YES;
    }
    return _toolView;
}

- (UIView *)touchView {
    if (!_touchView) {
        _touchView = [[UIView alloc] init];
        _touchView.backgroundColor = [UIColor clearColor];
    }
    return _touchView;
}

- (UILabel *)currentTimeLbl {
    
    if (!_currentTimeLbl) {
        _currentTimeLbl = [[UILabel alloc]init];
        _currentTimeLbl.textColor = [UIColor whiteColor];
        _currentTimeLbl.font = [UIFont systemFontOfSize:10.0];
        _currentTimeLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _currentTimeLbl;
}

- (UILabel *)totalTimeLbl {
    
    if (!_totalTimeLbl) {
        _totalTimeLbl = [[UILabel alloc]init];
        _totalTimeLbl.textColor = [UIColor whiteColor];
        _totalTimeLbl.font = [UIFont systemFontOfSize:10.0];
        _totalTimeLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _totalTimeLbl;
}

- (UIProgressView *)videoProgressView {
    
    if (!_videoProgressView) {
        _videoProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _videoProgressView.progressTintColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5];  //填充部分颜色
        _videoProgressView.trackTintColor = [UIColor clearColor];   // 未填充部分颜色
        _videoProgressView.layer.cornerRadius = 0.5;
        _videoProgressView.layer.masksToBounds = YES;
        CGAffineTransform transform = CGAffineTransformMakeScale(1.0, 1.0);
        _videoProgressView.transform = transform;
    }
    return _videoProgressView;
}

- (UIProgressView *)bottomProgress {
    if (!_bottomProgress) {
        _bottomProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _bottomProgress.progressTintColor = [UIColor blueColor];//填充部分颜色
        _bottomProgress.trackTintColor = [UIColor clearColor];   // 未填充部分颜色
        _bottomProgress.layer.cornerRadius = 0.5;
        _bottomProgress.layer.masksToBounds = YES;
        CGAffineTransform transform = CGAffineTransformMakeScale(1.0, 1.0);
        _bottomProgress.transform = transform;
        _bottomProgress.hidden = YES;
    }
    return _bottomProgress;
}

- (UISlider *)playSlider {
    if (!_playSlider) {
        _playSlider = [[UISlider alloc] init];
        [_playSlider setThumbImage:[UIImage imageNamed:NBImageName(@"icon_progress")] forState:UIControlStateNormal];
        _playSlider.minimumTrackTintColor = [UIColor whiteColor];
        _playSlider.maximumTrackTintColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
        [_playSlider addTarget:self action:@selector(playSliderChange:) forControlEvents:UIControlEventValueChanged]; //拖动滑竿更新时间
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpInside];  //松手,滑块拖动停止
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpOutside];
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchCancel];
    }
    
    return _playSlider;
}

- (UIButton *)stopButton {
    if (!_stopButton) {
        _stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_stopButton addTarget:self action:@selector(resumeOrPause) forControlEvents:UIControlEventTouchUpInside];
        
        [_stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause")] forState:UIControlStateNormal];
        [_stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play")] forState:UIControlStateSelected];
    }
    return _stopButton;
}

- (UIButton *)screenButton {
    if (!_screenButton) {
        _screenButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_screenButton addTarget:self action:@selector(fullScreen) forControlEvents:UIControlEventTouchUpInside];
        [_screenButton setImage:[UIImage imageNamed:NBImageName(@"icon_full")] forState:UIControlStateNormal];
        [_screenButton setImage:[UIImage imageNamed:NBImageName(@"icon_full")] forState:UIControlStateHighlighted];
    }
    return _screenButton;
}

- (UIButton *)repeatBtn {
    if (!_repeatBtn) {
        _repeatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repeatBtn setImage:[UIImage imageNamed:NBImageName(@"icon_repeat_video")] forState:UIControlStateNormal];
        [_repeatBtn addTarget:self action:@selector(repeatPlay) forControlEvents:UIControlEventTouchUpInside];
        _repeatBtn.hidden = YES;
    }
    return _repeatBtn;
}

- (UIButton *)playBtn {
    if (!_playBtn) {
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _playBtn.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        [_playBtn setImage:[UIImage imageNamed:NBImageName(@"play2")] forState:UIControlStateNormal];        [_playBtn.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(_playBtn);
            make.width.equalTo(@(50));
            make.height.equalTo(@(50));
        }];
        [_playBtn addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
        _playBtn.hidden = YES;
    }
    return _playBtn;
}

- (UIView *)netWorkPoorView {
    if (!_netWorkPoorView) {
        _netWorkPoorView = [[UIView alloc] init];
        _netWorkPoorView.hidden = YES;
    }
    return _netWorkPoorView;
}

- (UILabel *)errorLabel {
    if (!_errorLabel) {
        _errorLabel = [[UILabel alloc] init];
    }
    return _errorLabel;
}

- (UIActivityIndicatorView *)actIndicator {
    if (!_actIndicator) {
        _actIndicator = [[UIActivityIndicatorView alloc]init];
        _actIndicator.layer.cornerRadius = 10;
        _actIndicator.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        _actIndicator.layer.shadowColor = [UIColor blackColor].CGColor;//shadowColor阴影颜色
        _actIndicator.layer.shadowOffset = CGSizeMake(5,5);
        _actIndicator.layer.shadowOpacity = 0.5;//阴影透明度，默认0
        _actIndicator.layer.shadowRadius = 4;//阴影半径，默认3
        
        [_actIndicator addSubview:self.actIndicatorLabel];
        [self.actIndicatorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(_actIndicator).offset(44);
            make.left.right.bottom.equalTo(_actIndicator);
        }];
        
    }
    return _actIndicator;
}

- (UILabel *)actIndicatorLabel {
    if (!_actIndicatorLabel) {
        _actIndicatorLabel = [[UILabel alloc] init];
        [_actIndicatorLabel setFont:[UIFont systemFontOfSize:12]];
        _actIndicatorLabel.textAlignment = NSTextAlignmentCenter;
        _actIndicatorLabel.textColor = [UIColor whiteColor];
        _actIndicatorLabel.text = @"正在加载, 请稍等";
    }
    return _actIndicatorLabel;
}

- (MPVolumeView *)volumeView {
    if (!_volumeView) {
        _volumeView = [[MPVolumeView alloc] init];
        _volumeView.showsRouteButton = NO;
        _volumeView.showsVolumeSlider = NO;
        for (UIView * view in _volumeView.subviews) {
            if ([NSStringFromClass(view.class) isEqualToString:@"MPVolumeSlider"]) {
                self.volumeSlider = (UISlider *)view;
                break;
            }
        }
        NSLog(@"%f %f", _volumeView.frame.size.width, _volumeView.frame.size.height);
    }
    return _volumeView;
}

- (NBTimeSheetView *)timeSheetView {
    if (!_timeSheetView) {
        _timeSheetView = [[NBTimeSheetView alloc]initWithFrame:CGRectMake(0, 0, 120, 60)];
        _timeSheetView.hidden = YES;
        _timeSheetView.layer.cornerRadius = 10.0;
    }
    return _timeSheetView;
}

- (void)setIsShowFullScreen:(BOOL)isShowFullScreen {
    self.screenButton.hidden = !isShowFullScreen;
}

#pragma mark - 设置进度条、暂停、全屏等组件

- (void)setVideoToolView {
    __weak typeof(self) weakSelf = self;
    
    self.playerView.userInteractionEnabled = YES;
    
//    [self.playerView removeFromSuperview];
//    [_showView addSubview:self.playerView];
//    [self.playerView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.top.mas_equalTo(0);
//        make.right.mas_equalTo(0);
//        make.bottom.mas_equalTo(0);
//        make.left.mas_equalTo(0);
//    }];
    
    // 横屏的时候显示status bar
//    [self.statusBarBgView removeFromSuperview];
//    [self.playerView addSubview:self.statusBarBgView];
//    [self.statusBarBgView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.mas_equalTo(0);
//        make.top.mas_equalTo(0);
//        make.right.mas_equalTo(0);
//        make.height.mas_equalTo(20);
//    }];
    
    [self.toolView removeFromSuperview];
    [self.playerView addSubview:self.toolView];
    [self.toolView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.playerView);
        make.bottom.equalTo(self.playerView).offset(0);
        make.height.mas_equalTo(44);
    }];
    
    [self.stopButton removeFromSuperview];
    [self.toolView addSubview:self.stopButton];
    [self.stopButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.left.mas_equalTo(0);
        make.width.mas_equalTo(44);
        make.height.mas_equalTo(44);
    }];
    
    [self.screenButton removeFromSuperview];
    [self.toolView addSubview:self.screenButton];
    [self.screenButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.width.mas_equalTo(44);
        make.height.mas_equalTo(44);
    }];
    
    // 当前播放时间
    self.currentTimeLbl.frame = CGRectMake(44, 0, 52, 44);
    [self.currentTimeLbl removeFromSuperview];
    [self.toolView addSubview:self.currentTimeLbl];
    [self.currentTimeLbl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(44);
        make.top.mas_equalTo(0);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(44);
    }];
    [self updateCurrentTime:0];
    
    // 总共播放时间
    [self.totalTimeLbl removeFromSuperview];
    [self.toolView addSubview:self.totalTimeLbl];
    [self.totalTimeLbl mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.right.equalTo(weakSelf.screenButton.mas_left);
        make.width.mas_equalTo(52);
        make.height.mas_equalTo(44);
    }];
    
    [self.playSlider removeFromSuperview];
    [self.toolView addSubview:self.playSlider];
    [self.playSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.currentTimeLbl.mas_right);
        make.top.bottom.equalTo(self.toolView);
        make.right.equalTo(self.totalTimeLbl.mas_left);
    }];
    
    // 进度条
    [self.videoProgressView removeFromSuperview];
    [self.toolView addSubview:self.videoProgressView];
    [self.videoProgressView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.currentTimeLbl.mas_right);
        make.right.equalTo(self.totalTimeLbl.mas_left);
        make.centerY.equalTo(weakSelf.playSlider.mas_centerY).offset(1);
        make.height.mas_equalTo(1);
    }];
    
    [self.bottomProgress removeFromSuperview];
    [self.playerView addSubview:self.bottomProgress];
    [self.bottomProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.playerView);
        make.height.mas_equalTo(2);
    }];
    
    // 加载旋转菊花
    [self.actIndicator removeFromSuperview];
    [self.playerView addSubview:self.actIndicator];
    [self.actIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.playerView);
        make.centerY.equalTo(self.playerView);
        make.width.mas_equalTo(120);
        make.height.mas_equalTo(70);
    }];
    
    [self.touchView removeFromSuperview];
    [self.playerView addSubview:self.touchView];
    [self.touchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.playerView);
        make.left.equalTo(weakSelf.playerView);
        make.right.equalTo(weakSelf.playerView);
        make.bottom.equalTo(weakSelf.playerView).offset(-44);
    }];
    
    // 音量控制view
    [self.volumeView removeFromSuperview];
    [self.playerView addSubview:self.volumeView];
    
    // 快进⏩
    [self.timeSheetView removeFromSuperview];
    [self.playerView addSubview:self.timeSheetView];
    [self.timeSheetView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.playerView);
        make.width.equalTo(@(120));
        make.height.equalTo(@60);
    }];
    
    [self.repeatBtn removeFromSuperview];
    [self.playerView addSubview:self.repeatBtn];
    [self.repeatBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.playerView);
    }];
    self.repeatBtn.hidden = YES;
    
    [self.playBtn removeFromSuperview];
    [self.playerView addSubview:self.playBtn];
    [self.playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.playerView);
    }];
    self.playBtn.hidden = YES;
    
    [self.netWorkPoorView removeFromSuperview];
    [self.playerView addSubview:self.netWorkPoorView];
    [self.netWorkPoorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.playerView).offset(0);
    }];
    self.netWorkPoorView.hidden = YES;
    
    [self.errorLabel removeFromSuperview];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.font = [UIFont systemFontOfSize:12];
    self.errorLabel.text = @"网络不佳，请点击屏幕重试";
    self.errorLabel.textColor = [UIColor whiteColor];
    [self.netWorkPoorView addSubview:self.errorLabel];
    [self.errorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.netWorkPoorView).offset(0);
        make.centerY.equalTo(self.netWorkPoorView);
        make.height.equalTo(@(100));
    }];
    
    UITapGestureRecognizer *tapRefresh = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRefresh:)];
    [self.netWorkPoorView addGestureRecognizer:tapRefresh];
    
    UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    tap.numberOfTapsRequired = 1;
    tap.numberOfTouchesRequired = 1;
    tap.delegate = self;
    [self.touchView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelegate:self];
    [self.touchView addGestureRecognizer:panRecognizer];
    
    UITapGestureRecognizer *sliderTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(sliderTapAction:)];
    sliderTap.numberOfTapsRequired = 1;
    sliderTap.numberOfTouchesRequired = 1;
    sliderTap.delegate = self;
    [self.playSlider addGestureRecognizer:sliderTap];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if (_controlJudge) {
        return NO;
    }else{
        return YES;
    }
}

#pragma mark - 手势Action

- (void)tapAction:(UITapGestureRecognizer *)tap{
    if (!self.canTapTouchView) {
        return;
    }
    //点击一次
    if (tap.numberOfTapsRequired == 1) {
        if (self.toolView.hidden) {
            [self showToolView];
        } else {
            [self toolViewHidden];
        }
    } else if(tap.numberOfTapsRequired == 2){
        [self resumeOrPause];
    }
}

- (void)tapRefresh:(UITapGestureRecognizer *)tap {
    
    [self hideNetWorkPoorView];
    
    if (_cacheType == NBPlayerCacheTypePlayAfterCache) {
        if (self.downloadSession) {
            [self.downloadSession refreshDownload];
        }
        return;
    }
    NSLog(@"tapRefresh state :%ld",(long)self.state);
    if (self.state == NBPlayerStateFailed) {
        if (self.requestFailed) {
            NSLog(@"错了错了，重试");
            [self.resouerLoader.task continueLoading];
            return;
        }
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
            NSLog(@"删除了删除了");
            [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:nil];
        }
        NSLog(@"重试了重试了");
        [self playWithUrl:_playUrl showView:_showView cacheType:_cacheType];
        return;
    }
    
    
    if (isHLS) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.m3u8Handler refreshTask:self.nextTs completeWithError:^(NSError *error, NSInteger nextTs) {
                if (error) {
                    [self showNetWorkPoorView];
                    return ;
                }
            }];
            
        });
    }
    
}

- (void)sliderTapAction:(UITapGestureRecognizer *)tap {
    if (tap.numberOfTapsRequired == 1) {
        NSLog(@"点击了playSlider");
        CGPoint touchPoint = [tap locationInView:self.playSlider];
        NSLog(@"(%f,%f)", touchPoint.x, touchPoint.y);
        NSLog(@"%f duration:%f", self.playSlider.frame.size.width, self.duration);
        
        float value = (touchPoint.x / self.playSlider.frame.size.width) * self.playSlider.maximumValue;
        
        [self seekToTime:value completionHandler:nil];
        [self updateCurrentTime:value];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    
    // 只有在播放中，或者缓存中，才可以改变进度等
    if (self.state != NBPlayerStatePlaying && self.state != NBPlayerStateBuffering) {
        return;
    }
    
    CGPoint touchPoint = [recognizer locationInView:self.touchView];
    NSLog(@"(%f,%f)", touchPoint.x, touchPoint.y);
    
    if ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateBegan) {
        //触摸开始, 初始化一些值
        _hasMoved = NO;
        _controlJudge = NO;
        _touchBeginValue = self.playSlider.value;
        _touchBeginVoiceValue = _volumeSlider.value;
        _touchBeginLightValue = [UIScreen mainScreen].brightness;
        _touchBeginPoint = touchPoint;
    }
    
    if ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateChanged) {
        
        //如果移动的距离过于小, 就判断为没有移动
        if (fabs(touchPoint.x - _touchBeginPoint.x) < LeastMoveDistance && fabs(touchPoint.y - _touchBeginPoint.y) < LeastMoveDistance) {
            return;
        }
        
        _hasMoved = YES;
        
        //如果还没有判断出是什么手势就进行判断
        if (!_controlJudge) {
            //根据滑动角度的tan值来进行判断
            float tan = fabs(touchPoint.y - _touchBeginPoint.y) / fabs(touchPoint.x - _touchBeginPoint.x);
            
            //当滑动角度小于30度的时候, 进度手势
            if (tan < 1 / sqrt(3)) {
                self.controlType = NBPlayerControlTypeProgress;
                _controlJudge = YES;
            }
            
            //当滑动角度大于60度的时候, 声音和亮度
            else if (tan > sqrt(3)) {
                //判断是在屏幕的左半边还是右半边滑动, 左侧控制为亮度, 右侧控制音量
                if (_touchBeginPoint.x < self.touchView.frame.size.width / 2) {
                    _controlType = NBPlayerControlTypeLight;
                }else{
                    _controlType = NBPlayerControlTypeVoice;
                }
                _controlJudge = YES;
            } else {
                _controlType = NBPlayerControlTypeNone;
                return;
            }
        }
        
        if (NBPlayerControlTypeProgress == _controlType) {
            [self.player pause];
            [self unmonitoringPlayback];
            float value = [self moveProgressControllWithTempPoint:touchPoint];
            [self timeValueChangingWithValue:value];
        } else if (NBPlayerControlTypeVoice == _controlType) {
            //根据触摸开始时的音量和触摸开始时的点去计算出现在滑动到的音量
            float voiceValue = _touchBeginVoiceValue - ((touchPoint.y - _touchBeginPoint.y) / CGRectGetHeight(self.touchView.frame));
            //判断控制一下, 不能超出 0~1
            if (voiceValue < 0) {
                self.volumeSlider.value = 0;
            }else if(voiceValue > 1){
                self.volumeSlider.value = 1;
            }else{
                self.volumeSlider.value = voiceValue;
            }
        } else if (NBPlayerControlTypeLight == _controlType) {
            [UIScreen mainScreen].brightness -= ((touchPoint.y - _touchBeginPoint.y) / 10000);
        } else if (NBPlayerControlTypeNone == _controlType) {
            if (self.toolView.hidden) {
                [self showToolView];
            } else {
                [self toolViewHidden];
            }
        }
        
    }
    
    if (([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateEnded) || ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateCancelled)) {
        CGFloat x = recognizer.view.center.x;
        CGFloat y = recognizer.view.center.y;
        
        NSLog(@"%lf,%lf", x, y);
        _controlJudge = NO;
        //判断是否移动过,
        if (_hasMoved) {
            if (NBPlayerControlTypeProgress == _controlType) {
                float value = [self moveProgressControllWithTempPoint:touchPoint];
                _current = value;
                __weak __typeof(self)weakSelf = self;
                if (isHLS ) {
                    
                    double persent = value/self.duration;
                    if (persent < self.loadedProgress) {
                        [self seekToTime:value completionHandler:^(BOOL finished) {
                            __strong __typeof(weakSelf) strongSelf = weakSelf;
                            
                            [strongSelf monitoringPlayback:strongSelf.player.currentItem];
                        }];
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerCurrentTimeChangedNofification object:nil userInfo:@{@"currentTime":@(value)}];
                } else {
                    [self seekToTime:value completionHandler:^(BOOL finished) {
                        __strong __typeof(weakSelf) strongSelf = weakSelf;
                        
                        [strongSelf monitoringPlayback:strongSelf.player.currentItem];
                    }];
                    self.resouerLoader.isDrag = YES;
                }
                
                self.timeSheetView.hidden = YES;
                [self updateCurrentTime:value];
                [self updateVideoSlider:value];
            }
        }
    }
}

#pragma mark - 用来控制移动过程中计算手指划过的时间
-(float)moveProgressControllWithTempPoint:(CGPoint)tempPoint {
    float tempValue = _touchBeginValue + TotalScreenTime * ((tempPoint.x - _touchBeginPoint.x) / kScreenWidth);
    if (tempValue > self.duration) {
        tempValue = self.duration;
    }else if (tempValue < 0){
        tempValue = 0.0f;
    }
    return tempValue;
}

#pragma mark - 用来显示时间的view在时间发生变化时所作的操作
-(void)timeValueChangingWithValue:(float)value {
    if (value > _touchBeginValue) {
        _timeSheetView.sheetStateImageView.image = [UIImage imageNamed:NBImageName(@"progress_icon_r")];
    }else if(value < _touchBeginValue){
        _timeSheetView.sheetStateImageView.image = [UIImage imageNamed:NBImageName(@"progress_icon_l")];
    }
    _timeSheetView.hidden = NO;
    NSString * tempTime = [NSString calculateTimeWithTimeFormatter:value];
    if (tempTime.length > 5) {
        _timeSheetView.sheetTimeLabel.text = [NSString stringWithFormat:@"00:%@/%@", tempTime, self.totalTimeLbl.text];
    }else{
        _timeSheetView.sheetTimeLabel.text = [NSString stringWithFormat:@"%@/%@", tempTime, self.totalTimeLbl.text];
    }
}

#pragma mark - Slider相关

// 拖动slider 播放跳跃播放
- (void)seekToTime:(CGFloat)seconds completionHandler:(void (^)(BOOL finished))completionHandler{
    NSLog(@"seekToTime");
    if (self.state == NBPlayerStateFailed || self.state == NBPlayerStateDefault || self.state == NBPlayerStateWillPlay) {
        return;
    }
    
    seconds = MAX(0, seconds);
    seconds = MIN(seconds, self.duration);
    
    [self.player pause];
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        self.netWorkPoorView.hidden = YES;
        
        NSLog(@"是否结束：%@",@"完成");
        
        self.state = NBPlayerStatePlaying;
        
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            self.state = NBPlayerStateBuffering;
            [self.player play];
        } else {
            self.isPauseByUser = NO;
            [self.player play];
        }
        
        if (completionHandler) {
            completionHandler(finished);
        }
        if (!self.autoPlay) {
            [self pause];
        }
    }];
}

//手指结束拖动，播放器从当前点开始播放，开启滑竿的时间走动
- (void)playSliderChangeEnd:(UISlider *)slider {
    _current = slider.value;
//    [self.player pause];
    self.playSlider.selected = NO;
    __weak __typeof(self)weakSelf = self;
    if (isHLS) {
        double persent = slider.value/slider.maximumValue;
        if (persent < self.loadedProgress) {
            [self seekToTime:slider.value completionHandler:^(BOOL finished) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                
                [strongSelf monitoringPlayback:strongSelf.player.currentItem];
            }];
        }
    } else {
        [self seekToTime:_current completionHandler:^(BOOL finished) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf monitoringPlayback:strongSelf.player.currentItem];
        }];
        self.resouerLoader.isDrag = YES;
    }
    
    
    [self updateCurrentTime:slider.value];
    
    if (isHLS ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerCurrentTimeChangedNofification object:nil userInfo:@{@"currentTime":@(slider.value)}];
    }
}

//手指正在拖动，播放器继续播放，但是停止滑竿的时间走动
- (void)playSliderChange:(UISlider *)slider {
    [self unmonitoringPlayback];
    self.playSlider.selected = YES;
    [_hiddenTimer invalidate];
    [self updateCurrentTime:slider.value];
}

// 设置slider最小值和最大值
- (void)setPlaySliderValue:(CGFloat)time {
    self.playSlider.minimumValue = 0.0;
    self.playSlider.maximumValue = (NSInteger)time;
}

/**
 *  更新当前播放时间
 *
 *  @param time 但前播放时间秒数
 */
- (void)updateCurrentTime:(CGFloat)time {
    long videocurrent = ceil(time);
    
    NSString *str = nil;
    if (videocurrent < 3600) {
        str =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videocurrent/60.f)),lround(floor(videocurrent/1.f))%60];
    } else {
        str =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videocurrent/3600.f)),lround(floor(videocurrent%3600)/60.f),lround(floor(videocurrent/1.f))%60];
    }
    
    self.currentTimeLbl.text = str;
}

/**
 *  更新所有时间
 *
 *  @param time 时间（秒）
 */
- (void)updateTotolTime:(CGFloat)time {
    long videoLenth = ceil(time);
    NSString *strtotol = nil;
    if (videoLenth < 3600) {
        strtotol =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videoLenth/60.f)),lround(floor(videoLenth/1.f))%60];
    } else {
        strtotol =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videoLenth/3600.f)),lround(floor(videoLenth%3600)/60.f),lround(floor(videoLenth/1.f))%60];
    }
    
    self.totalTimeLbl.text = strtotol;
}

/**
 *  更新Slider
 *
 *  @param currentSecond 但前播放时间进度
 */
- (void)updateVideoSlider:(CGFloat)currentSecond {
//    NSLog(@"当前播放时间进度: %f",currentSecond);
    [self.playSlider setValue:currentSecond animated:NO];
    
    [self.bottomProgress setProgress:currentSecond/self.playSlider.maximumValue animated:NO];
}

#pragma mark - 暂停播放相关方法

/**
 *  暂停或者播放
 */
- (void)resumeOrPause {
    if (!self.currentPlayerItem) {
        return;
    }
    
    if (self.player.rate == 1) {
        self.state = NBPlayerStatePlaying;
    }
    
    self.isPauseByUser = NO;
    
    if (self.state == NBPlayerStatePlaying ) {
        [self.stopButton setSelected:YES];
        [self.player pause];
        self.isPauseByUser = YES;
        self.playBtn.hidden = NO;
        self.state = NBPlayerStatePause;
    } else if (self.state == NBPlayerStatePause || self.state == NBPlayerStateWillPlay || self.state == NBPlayerStateBuffering) {
        self.repeatBtn.hidden = YES;
        [self.stopButton setSelected:NO];
        [self.player play];
//        self.state = NBPlayerStatePlaying;
        self.playBtn.hidden = YES;
    } else if (self.state == NBPlayerStateFinish) {
        self.repeatBtn.hidden = YES;
        [self.stopButton setSelected:NO];
        [self seekToTime:0.0 completionHandler:nil];
        self.state = NBPlayerStatePlaying;
        self.playBtn.hidden = YES;
        _current = 0;
    }
    
}

/**
 *  重播
 */
- (void)repeatPlay {
    _current = 0;
//    [self showToolView];
    self.repeatBtn.hidden = YES;
    [self.stopButton setSelected:NO];
    [self playWithUrl:_playUrl showView:_showView cacheType:_cacheType];
    self.isRepeated = NO;
}

- (void)startPlay {
    _current = 0;
    _playBtn.hidden = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
        if (isHLS) {
            localURL = [NSURL URLWithString:[httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%@",cacheVieoName]]];
        }
        [self playWithLocalUrl:localURL];
        if (isHLS && self.player.currentItem.status != AVPlayerStatusReadyToPlay) {
            [self seekToTime:_current completionHandler:nil];
        }
        
    }
}

/**
 *  重新播放
 */
- (void)resume {
    if (!self.currentPlayerItem) {
        return;
    }
    [self.stopButton setSelected:NO];
    self.isPauseByUser = NO;
    [self.player play];
    self.state = NBPlayerStatePlaying;
}

/**
 *  暂停播放
 */
- (void)pause {
    if (!self.currentPlayerItem) {
        return;
    }
    [self.stopButton setSelected:YES];
    self.isPauseByUser = YES;
    self.state = NBPlayerStatePause;
    [self.player pause];
}

/**
 *  停止播放
 */
- (void)stop {
    self.isPauseByUser = YES;
    self.loadedProgress = 0;
    self.duration = 0;
    self.current  = 0;
    self.state = NBPlayerStateFailed;
    [self releasePlayer];
    self.repeatBtn.hidden = YES;
    [self toolViewHidden];
    self.m3u8Handler = nil;
    [self.httpServer stop];
    self.resouerLoader = nil;
}

#pragma mark - 计算播放进度

/**
 *  计算播放进度
 *
 *  @return 播放时间进度
 */
- (CGFloat)progress {
    if (self.duration > 0) {
        return self.current / self.duration;
    }
    
    return 0;
}

#pragma mark - 工具条隐藏或者显示

- (void)toolViewHidden {
    self.toolView.hidden = YES;
    self.statusBarBgView.hidden = YES;
    
    self.bottomProgress.hidden = NO;
    
//    if (_isFullScreen) {
//        [[UIApplication sharedApplication] setStatusBarHidden:YES];
//    }
    [_hiddenTimer invalidate];
}

- (void)showToolView {
    
    if (!self.repeatBtn.hidden) {
        return;
    }
    self.toolView.hidden = NO;
    self.bottomProgress.hidden = YES;
    
    if (_isFullScreen) {
        self.statusBarBgView.hidden = NO;
    } else {
        self.statusBarBgView.hidden = YES;
    }
    
//    if ([UIApplication sharedApplication].statusBarHidden) {
//        [[UIApplication sharedApplication] setStatusBarHidden:NO];
//    }
    
    [self createTimer];
}

#pragma mark - private

- (void)showNetWorkPoorView {
    self.netWorkPoorView.hidden = NO;
    self.downloadFailed = YES;
    self.actIndicator.hidden = YES;
    [self.actIndicator stopAnimating];
    self.state = NBPlayerStateFailed;
}

- (void)hideNetWorkPoorView {
    self.netWorkPoorView.hidden = YES;
    self.downloadFailed = NO;
    self.actIndicator.hidden = NO;
    [self.actIndicator startAnimating];
}

- (void)removeDownloadSessionObserver {
    if (self.downloadSession) {
        
        [self.downloadSession removeObserver:self forKeyPath:@"downloadProgress"];
        [self.downloadSession removeObserver:self forKeyPath:@"startPlay"];
        
    }
}

- (void)releaseDownloadSession {
    if (self.downloadSession) {
        [self.downloadSession cancel];
        self.downloadSession = nil;
    }
}

- (void)releaseResouerLoader {
    if (self.resouerLoader.task) {
        [self.resouerLoader.task cancel];
        self.resouerLoader.task = nil;
        self.resouerLoader = nil;
    }
}

- (void)removeCommonPlayerObserver {
    if (!self.currentPlayerItem) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemStatusKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemLoadedTimeRangesKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPlaybackBufferEmptyKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPresentationSizeKeyPath];
    
    [self unmonitoringPlayback];
    
    self.currentPlayerItem = nil;
    
    if (!self.player) {
        return;
    }
    
    [self.player removeObserver:self forKeyPath:@"rate"];
}

- (void)releasePlayer {
    [self.player pause];
    [self removeDownloadSessionObserver];
    [self releaseDownloadSession];
    [self removeCommonPlayerObserver];
    [self releaseResouerLoader];
    self.player = nil;
}

// 基本的监听
- (void)commonPlayerObserver {
    
    // status.播放器的播放状态
    [self.currentPlayerItem addObserver:self forKeyPath:NBVideoPlayerItemStatusKeyPath options:NSKeyValueObservingOptionNew context:nil];
    // loadedTimeRanges. 已加载项目的时间范围
    [self.currentPlayerItem addObserver:self forKeyPath:NBVideoPlayerItemLoadedTimeRangesKeyPath options:NSKeyValueObservingOptionNew context:nil];
    // playbackBufferEmpty. 指示播放是否已占用所有缓冲媒体，并且播放将停止或结束
    [self.currentPlayerItem addObserver:self forKeyPath:NBVideoPlayerItemPlaybackBufferEmptyKeyPath options:NSKeyValueObservingOptionNew context:nil];
    // playbackLikelyToKeepUp. 指示项目是否可能无阻塞地播放。
    [self.currentPlayerItem addObserver:self forKeyPath:NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath options:NSKeyValueObservingOptionNew context:nil];
    // presentationSize. 播放器呈现的大小size
    [self.currentPlayerItem addObserver:self forKeyPath:NBVideoPlayerItemPresentationSizeKeyPath options:NSKeyValueObservingOptionNew context:nil];
    
    [self.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    // 播放结束后，发送的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentPlayerItem];
    // 播放停顿后，调用此通知，有可能原因网络慢，不能正常加载
    // 当某些媒体未及时到达以继续播放时发布
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemPlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:self.currentPlayerItem];
}

- (void)localUrlPlayer {
    [self.player pause];
    NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
    if (isHLS) {
        localURL = [NSURL URLWithString:[httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%@",cacheVieoName]]];
    }
    [self playWithLocalUrl:localURL];
}

- (void)openHttpServer {
    if (!self.httpServer) {
        self.httpServer = [[HTTPServer alloc] init];
        [self.httpServer setType:@"_http._tcp."];  // 设置服务类型
        [self.httpServer setPort:12345]; // 设置服务器端口
        
        NSString *webPath = cachePathForVideo;
        
        NSLog(@"-------------\nSetting document root: %@\n", webPath);
        // 设置服务器路径
        [self.httpServer setDocumentRoot:webPath];
        NSError *error;
        if(![self.httpServer start:&error]) {
            NSLog(@"-------------\nError starting HTTP Server: %@\n", error);
        }
    } else {
        [self.httpServer setDocumentRoot:cachePathForVideo];
        if (!self.httpServer.isRunning) {
            [self.httpServer start:nil];
        }
    }
}

- (void)createTimer {
    if (!_hiddenTimer.valid) {
        _hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    }else{
        [_hiddenTimer invalidate];
        _hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    }
}

#pragma mark - NBLoaderURLSessionDelegate

- (void)didFinishLoadingWithTask:(NBVideoRequestTask *)task {
    if (self.state != NBPlayerStatePause) {
        [self.player play];
    }
}

//网络中断：-1005
//无网络连接：-1009
//请求超时：-1001
//服务器内部错误：-1004
//找不到服务器：-1003

- (void)didFailLoadingWithTask:(NBVideoRequestTask *)task withError:(NSInteger )errorCode {
    NSString *str = nil;
    switch (errorCode) {
        case -1001:
            str = @"请求超时";
            break;
        case -1003:
        case -1004:
            str = @"服务器错误";
            break;
        case -1005:
            str = @"网络中断";
            break;
        case -1009:
            str = @"无网络连接";
            break;
            
        default:
            str = [NSString stringWithFormat:@"%ld", (long)errorCode];
            break;
    }
    self.downloadFailed = YES;
    self.requestFailed = YES;
    self.errorLabel.text = str;
    if (self.state == NBPlayerStateDefault || self.state == NBPlayerStateBuffering || self.state == NBPlayerStateFailed) {
        [self showNetWorkPoorView];
    } else {
        // 失败了，还要继续尝试播放。
        [self.player play];
    }
    NSLog(@"失败了失败了%@", str);
}

#pragma mark - 通知中心检测到屏幕旋转
-(void)orientationChanged:(NSNotification *)notification {
    [self updateOrientation];
}

- (void)updateOrientation {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            [self toOrientation:UIInterfaceOrientationPortrait];
            break;
        case UIDeviceOrientationLandscapeLeft:
            [self toOrientation:UIInterfaceOrientationLandscapeRight];
            break;
        case UIDeviceOrientationLandscapeRight:
            [self toOrientation:UIInterfaceOrientationLandscapeLeft];
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            [self toOrientation:UIInterfaceOrientationPortraitUpsideDown];
            break;
        default:
            break;
    }
}

#pragma mark - 全屏旋转处理

- (void)toOrientation:(UIInterfaceOrientation)orientation {
    
    if (!_canFullScreen) {
        return;
    }
    
    if (_currentOrientation == orientation) {
        return;
    }
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        NSNumber *va = [NSNumber numberWithInt:orientation];
        [[UIDevice currentDevice] setValue:va forKey:@"Orientation"];
        [self.playerView setFrame:self.showViewRect];
        
        self.isFullScreen = NO;
        
    } else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        
        NSNumber *va = [NSNumber numberWithInt:orientation];
        [[UIDevice currentDevice] setValue:va forKey:@"Orientation"];
        
        [self.playerView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.left.right.equalTo(_showView);
        }];
        self.isFullScreen = YES;
    }
    
    _currentOrientation = orientation;
    
    
    [UIView animateWithDuration:0.5 animations:^{
    } completion:^(BOOL finished) {
        
    }];
}

#pragma mark - 对外的API

- (void)play {
    self.playBtn.hidden = YES;
    self.autoPlay = YES;
    if (self.state == NBPlayerStateDefault) {
        [self startPlay];
    } else {
        if (self.state == NBPlayerStateFinish) {
            [self repeatPlay];
            return;
        }
        [self resumeOrPause];
    }
//    self.state = NBPlayerStatePlaying;
//    
//    [self showToolView];
}

- (void)makePalyerMute:(BOOL)isMute {
    self.player.muted = isMute;
}

- (void)seekToTime:(CGFloat)seconds withAutoPlay:(BOOL)autoPlay {
    self.autoPlay = autoPlay;
    [self seekToTime:seconds completionHandler:nil];
}

+ (void)clearAllVideoCache {
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    cachPath = [[NBPlayerEnvironment defaultEnvironment] cachePath];
    [fileManager removeItemAtPath:cachPath error:nil];
    
}

+ (double)allVideoCacheSize {
    
    double cacheVideoSize = 0.0f;
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    cachPath = [[NBPlayerEnvironment defaultEnvironment] cachePath];
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp4"] || [fileName.pathExtension isEqualToString:@"ts"]) {
            NSString *path = [cachPath stringByAppendingPathComponent: fileName];
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath: path error: nil ];
            cacheVideoSize += ((double)([fileAttributes fileSize ]) / 1024.0 / 1024.0);
        }
    }
    
    return cacheVideoSize;
}

- (void)dealloc {
    NSLog(@"%@",@"NBVideoPlayer dealloc");
    [self unmonitoringPlayback];
}

@end
