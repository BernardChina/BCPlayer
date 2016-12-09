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
}

@property (nonatomic, strong)HTTPServer * httpServer;

@property (nonatomic, assign) NBPlayerState state;
@property (nonatomic, assign) CGFloat        loadedProgress;
@property (nonatomic, assign) CGFloat        duration;
@property (nonatomic, assign) CGFloat        current;

@property (nonatomic, strong) AVURLAsset     *videoURLAsset;
@property (nonatomic, strong) AVAsset        *videoAsset;
@property (nonatomic, strong) AVPlayer       *player;
@property (nonatomic, strong) AVPlayerItem   *currentPlayerItem;
@property (nonatomic, strong) NSObject       *playbackTimeObserver;
@property (nonatomic, assign) BOOL           isPauseByUser;           //是否被用户暂停

@property (nonatomic, weak  ) UIView         *showView;
@property (nonatomic, assign) CGRect         showViewRect;            //视频展示ViewRect
@property (nonatomic, strong) NBPlayerView  *playerView;
@property (nonatomic, strong) UIView         *touchView;              //事件响应View
@property (nonatomic, weak  ) UIView         *playerSuperView;        //播放界面的父页面

@property (nonatomic, strong) UIView         *statusBarBgView;        //全屏状态栏的背景view
@property (nonatomic, strong) UIView         *toolView;
@property (nonatomic, strong) UILabel        *currentTimeLbl;         //当前播放时间
@property (nonatomic, strong) UILabel        *totalTimeLbl;           //总共播放时间
@property (nonatomic, strong) UIProgressView *videoProgressView;      //缓冲进度条
@property (nonatomic, strong) UISlider       *playSlider;             //滑竿
@property (nonatomic, strong) UIButton       *stopButton;             //播放暂停按钮
@property (nonatomic, strong) UIButton       *screenButton;           //全屏按钮
@property (nonatomic, strong) UIButton       *repeatBtn;              //重播按钮
@property (nonatomic, assign) BOOL           isFullScreen;
@property (nonatomic, assign) BOOL           canFullScreen;
@property (nonatomic, strong) UIActivityIndicatorView *actIndicator;  //加载视频时的旋转菊花

@property (nonatomic, strong) MPVolumeView   *volumeView;             //音量控制控件
@property (nonatomic, strong) UISlider       *volumeSlider;           //用这个来控制音量

@property (nonatomic, strong) NBLoaderURLSession *resouerLoader;      //缓存session
@property (nonatomic, strong) NBDownloadURLSession *downloadSession;  //下载session

@property (nonatomic, assign) NBPlayerControlType controlType;       //当前手势是在控制进度、声音还是亮度
@property (nonatomic, strong) NBTimeSheetView *timeSheetView;        //左右滑动时间View
@property (nonatomic, strong) NSString *cachePath;

@end

@implementation NBVideoPlayer

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken;
    static NBVideoPlayer *instance;
    
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPauseByUser = YES;
        _loadedProgress = 0;
        _duration = 0;
        _current  = 0;
        _state = NBPlayerStateStopped;
        _stopInBackground = YES;
        _isFullScreen = NO;
        _canFullScreen = YES;
        
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

- (void)playWithVideoUrl:(NSURL *)url showView:(UIView *)showView andSuperView:(UIView *)superView {
    
    NSString *str = [url absoluteString];
    
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        
        self.resouerLoader          = [[NBLoaderURLSession alloc] init];
        self.resouerLoader.playCachePath = self.cachePath;
        self.resouerLoader.delegate = self;
        
        NSURL *playUrl              = getSchemeVideoURL(str);
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
    
    [self commonObserver];
    
    // 如果已经在NBPlayerStateBuffering，则直接发通知，否则设置状态
    if (self.state == NBPlayerStateBuffering) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerStateChangedNotification object:nil];
    } else {
        self.state = NBPlayerStateBuffering;
    }
    
}

- (void)openHttpServer {
    self.httpServer = [[HTTPServer alloc] init];
    [self.httpServer setType:@"_http._tcp."];  // 设置服务类型
    [self.httpServer setPort:12345]; // 设置服务器端口
    
    NSString *webPath = [[NBPlayerEnvironment defaultEnvironment] cachePath];
    
    NSLog(@"-------------\nSetting document root: %@\n", webPath);
    // 设置服务器路径
    [self.httpServer setDocumentRoot:webPath];
    NSError *error;
    if(![self.httpServer start:&error]) {
        NSLog(@"-------------\nError starting HTTP Server: %@\n", error);
    }
}

// 播放本地视频
- (void)playWithLocalUrl:(NSURL *)url {
    if (currentCacheType == NBPlayerCacheTypePlayHLS) {
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
    
    [self commonObserver];
    
    if ([url.scheme isEqualToString:@"file"]) {
        // 如果已经在NBPlayerStatePlaying，则直接发通知，否则设置状态
        if (self.state == NBPlayerStatePlaying) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerStateChangedNotification object:nil];
        } else {
            self.state = NBPlayerStatePlaying;
        }
    }
    
    [self setVideoToolView];
}

// 缓存后播放
- (void)playAfterCacheWithVideoUrl:(NSURL *)url {
    
    NSString *str = [url absoluteString];
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        self.downloadSession = [[NBDownloadURLSession alloc] init];
        [self.downloadSession addDownloadTask:str];
        
        [self.downloadSession addObserver:self forKeyPath:@"downloadProgress" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        [self.downloadSession addObserver:self forKeyPath:@"startPlay" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
    }
    
}
// 支持hls
- (void)playHLSWithUrl:(NSURL *)url {
    
    NSString *str = [url absoluteString];
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        NBPlayerM3U8Handler *handler = [[NBPlayerM3U8Handler alloc] init];
        self.downloadSession = [[NBDownloadURLSession alloc] init];
        handler.loadSession = self.downloadSession;
        [self.downloadSession addObserver:self forKeyPath:@"downloadProgress" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        [self.downloadSession addObserver:self forKeyPath:@"startPlay" options:NSKeyValueObservingOptionNew context:DownloadKVOContext];
        [handler praseUrl:url.absoluteString];
    }
}

- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView andSuperView:(UIView *)superView cacheType:(NBPlayerCacheType)cacheType {
    
    _playUrl = url;
    currentCacheType = cacheType;
    
    self.cachePath = saveCachePathForVideo(url.absoluteString);
    
    [self.player pause];
    [self releasePlayer];
    
    self.isPauseByUser = NO;
    self.loadedProgress = 0;
    self.duration = 0;
    self.current  = 0;
    
    _showView = showView;
    _showViewRect = showView.frame;
    _showView.backgroundColor = [UIColor blackColor];
    _playerSuperView = superView;
    
    // 假如有缓存文件，首先播放缓存文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
        NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
        if (currentCacheType == NBPlayerCacheTypePlayHLS) {
            localURL = [NSURL URLWithString:[httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%@",cacheVieoName]]];
        }
        [self playWithLocalUrl:localURL];
        return;
    }
    
    // 假如不缓存 或者 边播边缓存
    if (cacheType == NBPlayerCacheTypeNoCache || cacheType == NBPlayerCacheTypePlayWithCache) {
        [self playWithVideoUrl:url showView:showView andSuperView:superView];
    }
    
    // 缓存后再播放
    if (cacheType == NBPlayerCacheTypePlayAfterCache) {
        [self playAfterCacheWithVideoUrl:url];
    }
    // 支持hls
    if (cacheType == NBPlayerCacheTypePlayHLS) {
        [self playHLSWithUrl:url];
    }
    
    [self setVideoToolView];
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
        [self pause];
        self.state = NBPlayerStatePause;
        self.isPauseByUser = NO;
    }
}
- (void)appDidEnterPlayGround {
    if (!self.isPauseByUser) {
        [self resume];
        self.state = NBPlayerStatePlaying;
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    // 播放结束后，调用此通知，可以通过这个方法实现循环播放或者播放下个视频
    /*
     当播放结束后，播放头移动到playerItem的末尾，如果此时调用play方法是没有效果的，应该先把播放头移到player item起始位置。如果需要实现循环播放的功能，可以监听通知AVPlayerItemDidPlayToEndTimeNotification，当收到这个通知的时候，调用seekToTime：把播放头移动到起始位置[player seekToTime:kCMTimeZero];
     */
    //重新播放
    self.repeatBtn.hidden = NO;
    [self toolViewHidden];
    self.state = NBPlayerStateFinish;
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play")] forState:UIControlStateNormal];
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play_hl")] forState:UIControlStateHighlighted];
}

//在监听播放器状态中处理比较准确，播放停止了，有可能是网络原因
- (void)playerItemPlaybackStalled:(NSNotification *)notification {
    // 这里网络不好的时候，就会进入，不做处理，会在playbackBufferEmpty里面缓存之后重新播放
    NSLog(@"buffing----buffing");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    // 下载context
    if (context == DownloadKVOContext) {
        if ([object isEqual:self.downloadSession] && [keyPath isEqualToString:@"downloadProgress"]) {
            // 更改进度
            [self.videoProgressView setProgress:[[change objectForKey:NSKeyValueChangeNewKey] floatValue] animated:YES];
            [self.actIndicator startAnimating];
            self.actIndicator.hidden = NO;
            return;
        }
        if ([object isEqual:self.downloadSession] && [keyPath isEqualToString:@"startPlay"]) {
            // 下载完成
            [self.actIndicator stopAnimating];
            self.actIndicator.hidden = YES;
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
                NSURL *localURL = [NSURL fileURLWithPath:self.cachePath];
                if (currentCacheType == NBPlayerCacheTypePlayHLS) {
                    localURL = [NSURL URLWithString:[httpServerLocalUrl stringByAppendingString:[NSString stringWithFormat:@"%@",cacheVieoName]]];
                }
                [self playWithLocalUrl:localURL];
            }
            
            return;
        }
    }
    
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([NBVideoPlayerItemStatusKeyPath isEqualToString:keyPath]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            
            _hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
            [self monitoringPlayback:playerItem];// 给播放器添加计时器
            
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            [self stop];
        }
        
    } else if ([NBVideoPlayerItemLoadedTimeRangesKeyPath isEqualToString:keyPath]) {
        //监听播放器的下载进度
        [self calculateDownloadProgress:playerItem];
        
    } else if ([NBVideoPlayerItemPlaybackBufferEmptyKeyPath isEqualToString:keyPath]) {
        //监听播放器在缓冲数据的状态
        //指示播放是否已占用所有缓冲媒体，并且播放将停止或结束
        [self.actIndicator startAnimating];
        self.actIndicator.hidden = NO;
        if (playerItem.isPlaybackBufferEmpty) {
            self.state = NBPlayerStateBuffering;
            [self bufferingSomeSecond];
        }
    } else if ([NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath isEqualToString:keyPath]) {
        // playbackLikelyToKeepUp. 指示项目是否可能无阻塞地播放。
        NSLog(@"NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath");
    } else if ([NBVideoPlayerItemPresentationSizeKeyPath isEqualToString:keyPath]) {
        CGSize size = self.currentPlayerItem.presentationSize;
        static float staticHeight = 0;
        staticHeight = size.height/size.width * kScreenWidth;
        NSLog(@"%f", staticHeight);
        
        //用来监测屏幕旋转
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        _canFullScreen = YES;
    }
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    // playerItem.duration. 表示项目媒体的持续时间
    self.duration = playerItem.duration.value / playerItem.duration.timescale; //视频总时间
    [self.player play];
    [self updateTotolTime:self.duration];
    [self setPlaySliderValue:self.duration];
    
    __weak __typeof(self)weakSelf = self;
    // addPeriodicTimeObserverForInterval. 请求在回放期间周期性调用给定块以报告改变时间
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        // playerItem.currentTime. 返回项目的当前时间
        CGFloat current = playerItem.currentTime.value / playerItem.currentTime.timescale;
        [strongSelf updateCurrentTime:current];
        [strongSelf updateVideoSlider:current];
        if (strongSelf.isPauseByUser == NO) {
            strongSelf.state = NBPlayerStatePlaying;
        }
        
        // 不相等的时候才更新，并发通知，否则seek时会继续跳动
        if (strongSelf.current != current) {
            strongSelf.current = current;
            if (strongSelf.current > strongSelf.duration) {
                strongSelf.duration = strongSelf.current;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerProgressChangedNotification object:nil];
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
    self.loadedProgress = timeInterval / totalDuration;
    [self.videoProgressView setProgress:timeInterval / totalDuration animated:YES];
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
        }
    });
}

- (void)setLoadedProgress:(CGFloat)loadedProgress {
    if (_loadedProgress == loadedProgress) {
        return;
    }
    
    _loadedProgress = loadedProgress;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerLoadProgressChangedNotification object:nil];
}

- (void)setState:(NBPlayerState)state {
    if (state != NBPlayerStateBuffering) {
        [self.actIndicator stopAnimating];
        self.actIndicator.hidden = YES;
    }
    
    if (_state == state) {
        return;
    }
    
    _state = state;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerStateChangedNotification object:nil];
    
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
        [_stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause_hl")] forState:UIControlStateHighlighted];
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

- (UIActivityIndicatorView *)actIndicator {
    if (!_actIndicator) {
        _actIndicator = [[UIActivityIndicatorView alloc]init];
    }
    return _actIndicator;
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

#pragma mark - 设置进度条、暂停、全屏等组件

- (void)setVideoToolView {
    __weak typeof(self) weakSelf = self;
    
    _showView.userInteractionEnabled = YES;
    
    [self.playerView removeFromSuperview];
    [_showView addSubview:self.playerView];
    [self.playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.bottom.mas_equalTo(0);
        make.left.mas_equalTo(0);
    }];
    
    // 横屏的时候显示status bar
    [self.statusBarBgView removeFromSuperview];
    [_showView addSubview:self.statusBarBgView];
    [self.statusBarBgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.top.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.height.mas_equalTo(20);
    }];
    
    [self.toolView removeFromSuperview];
    [_showView addSubview:self.toolView];
    [self.toolView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.bottom.equalTo(weakSelf.showView);
        make.right.mas_equalTo(0);
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
        make.left.equalTo(weakSelf.currentTimeLbl.mas_right);
        make.top.mas_equalTo(0);
        make.right.equalTo(weakSelf.totalTimeLbl.mas_left);
        make.bottom.mas_equalTo(0);
    }];
    
    // 进度条
    [self.videoProgressView removeFromSuperview];
    [self.toolView addSubview:self.videoProgressView];
    [self.videoProgressView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(weakSelf.currentTimeLbl.mas_right);
        make.right.equalTo(weakSelf.totalTimeLbl.mas_left);
        make.centerY.equalTo(weakSelf.playSlider.mas_centerY).offset(1);
        make.height.mas_equalTo(1);
    }];
    
    // 加载旋转菊花
    [self.actIndicator removeFromSuperview];
    [_showView addSubview:self.actIndicator];
    [self.actIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(weakSelf.playerView);
        make.centerY.equalTo(weakSelf.playerView);
        make.width.mas_equalTo(44);
        make.height.mas_equalTo(44);
    }];
    
    [self.touchView removeFromSuperview];
    [_showView addSubview:self.touchView];
    [self.touchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.playerView);
        make.left.equalTo(weakSelf.playerView);
        make.right.equalTo(weakSelf.playerView);
        make.bottom.equalTo(weakSelf.playerView).offset(-44);
    }];
    
    // 音量控制view
    [self.volumeView removeFromSuperview];
    [_showView addSubview:self.volumeView];
    
    // 快进⏩
    [self.timeSheetView removeFromSuperview];
    [_showView addSubview:self.timeSheetView];
    [self.timeSheetView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(_showView);
        make.width.equalTo(@(120));
        make.height.equalTo(@60);
    }];
    
    [self.repeatBtn removeFromSuperview];
    [_showView addSubview:self.repeatBtn];
    [self.repeatBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(_showView);
    }];
    
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

- (void)sliderTapAction:(UITapGestureRecognizer *)tap {
    if (tap.numberOfTapsRequired == 1) {
        NSLog(@"点击了playSlider");
        CGPoint touchPoint = [tap locationInView:self.playSlider];
        NSLog(@"(%f,%f)", touchPoint.x, touchPoint.y);
        NSLog(@"%f duration:%f", self.playSlider.frame.size.width, self.duration);
        
        float value = (touchPoint.x / self.playSlider.frame.size.width) * self.playSlider.maximumValue;
        
        [self seekToTime:value];
        [self updateCurrentTime:value];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    
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
                [self seekToTime:value];
                self.timeSheetView.hidden = YES;
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
- (void)seekToTime:(CGFloat)seconds {
    if (self.state == NBPlayerStateStopped) {
        return;
    }
    
    seconds = MAX(0, seconds);
    seconds = MIN(seconds, self.duration);
    
    [self.player pause];
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        self.isPauseByUser = NO;
        [self.player play];
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            self.state = NBPlayerStateBuffering;
            
            self.actIndicator.hidden = NO;
            [self.actIndicator startAnimating];
        }
        
    }];
}

//手指结束拖动，播放器从当前点开始播放，开启滑竿的时间走动
- (void)playSliderChangeEnd:(UISlider *)slider {
    [self seekToTime:slider.value];
    [self updateCurrentTime:slider.value];
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause")] forState:UIControlStateNormal];
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause_hl")] forState:UIControlStateHighlighted];
}

//手指正在拖动，播放器继续播放，但是停止滑竿的时间走动
- (void)playSliderChange:(UISlider *)slider {
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
    [self.playSlider setValue:currentSecond animated:YES];
}

#pragma mark - 暂停播放相关方法

/**
 *  暂停或者播放
 */
- (void)resumeOrPause {
    if (!self.currentPlayerItem) {
        return;
    }
    if (self.state == NBPlayerStatePlaying) {
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play")] forState:UIControlStateNormal];
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play_hl")] forState:UIControlStateHighlighted];
        [self.player pause];
        self.state = NBPlayerStatePause;
    } else if (self.state == NBPlayerStatePause) {
        self.repeatBtn.hidden = YES;
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause")] forState:UIControlStateNormal];
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause_hl")] forState:UIControlStateHighlighted];
        [self.player play];
        self.state = NBPlayerStatePlaying;
    } else if (self.state == NBPlayerStateFinish) {
        self.repeatBtn.hidden = YES;
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause")] forState:UIControlStateNormal];
        [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause_hl")] forState:UIControlStateHighlighted];
        [self seekToTime:0.0];
        self.state = NBPlayerStatePlaying;
    }
    self.isPauseByUser = YES;
}

/**
 *  重播
 */
- (void)repeatPlay {
    [self showToolView];
    [self resumeOrPause];
}

/**
 *  重新播放
 */
- (void)resume {
    if (!self.currentPlayerItem) {
        return;
    }
    
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause")] forState:UIControlStateNormal];
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_pause_hl")] forState:UIControlStateHighlighted];
    self.isPauseByUser = NO;
    [self.player play];
}

/**
 *  暂停播放
 */
- (void)pause {
    if (!self.currentPlayerItem) {
        return;
    }
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play")] forState:UIControlStateNormal];
    [self.stopButton setImage:[UIImage imageNamed:NBImageName(@"icon_play_hl")] forState:UIControlStateHighlighted];
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
    self.state = NBPlayerStateStopped;
    [self.player pause];
    [self releasePlayer];
    self.repeatBtn.hidden = YES;
    [self toolViewHidden];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNBPlayerProgressChangedNotification object:nil];
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
    
    if (_isFullScreen) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }
    [_hiddenTimer invalidate];
}

- (void)showToolView {
    
    if (!self.repeatBtn.hidden) {
        return;
    }
    self.toolView.hidden = NO;
    
    if (_isFullScreen) {
        self.statusBarBgView.hidden = NO;
    } else {
        self.statusBarBgView.hidden = YES;
    }
    
    if ([UIApplication sharedApplication].statusBarHidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
    if (!_hiddenTimer.valid) {
        _hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    }else{
        [_hiddenTimer invalidate];
        _hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    }
}

#pragma mark - private

- (void)releasePlayer {
    if (currentCacheType == NBPlayerCacheTypePlayAfterCache && self.downloadSession) {
        
        [self.downloadSession removeObserver:self forKeyPath:@"downloadProgress"];
        [self.downloadSession removeObserver:self forKeyPath:@"startPlay"];
        
        [self.downloadSession cancel];
        self.downloadSession = nil;
    }
    
    if (!self.currentPlayerItem) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemStatusKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemLoadedTimeRangesKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPlaybackBufferEmptyKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPlaybackLikelyToKeepUpKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:NBVideoPlayerItemPresentationSizeKeyPath];
    [self.player removeTimeObserver:self.playbackTimeObserver];
    self.playbackTimeObserver = nil;
    self.currentPlayerItem = nil;
    
    if (self.resouerLoader.task) {
        [self.resouerLoader.task cancel];
        self.resouerLoader.task = nil;
        self.resouerLoader = nil;
    }
    
}

// 基本的监听
- (void)commonObserver {
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    // 播放结束后，发送的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentPlayerItem];
    // 播放停顿后，调用此通知，有可能原因网络慢，不能正常加载
    // 当某些媒体未及时到达以继续播放时发布
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemPlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:self.currentPlayerItem];
}

#pragma mark - NBLoaderURLSessionDelegate

- (void)didFinishLoadingWithTask:(NBVideoRequestTask *)task {

    
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
            str = [NSString stringWithFormat:@"%@", @"(_errorCode)"];
            break;
    }
    
    NSLog(@"%@", str);
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
    
    //    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    if (_currentOrientation == orientation) {
        return;
    }
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        [self.showView removeFromSuperview];
        [self.playerSuperView addSubview:self.showView];
        
        NBLightView *lightView = [NBLightView sharedInstance];
        [[UIApplication sharedApplication].keyWindow bringSubviewToFront:lightView];
        __weak NBVideoPlayer * weakSelf = self;
        [self.showView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(CGRectGetMinY(weakSelf.showViewRect));
            make.left.mas_equalTo(CGRectGetMinX(weakSelf.showViewRect));
            make.width.mas_equalTo(CGRectGetWidth(weakSelf.showViewRect));
            make.height.mas_equalTo(CGRectGetHeight(weakSelf.showViewRect));
        }];
        
        [lightView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo([UIApplication sharedApplication].keyWindow);
            make.centerY.equalTo([UIApplication sharedApplication].keyWindow).offset(-5);
            make.width.mas_equalTo(155);
            make.height.mas_equalTo(155);
        }];
    } else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        [self.showView removeFromSuperview];
        [[UIApplication sharedApplication].keyWindow addSubview:self.showView];
        
        // 亮度view加到window最上层
        NBLightView *lightView = [NBLightView sharedInstance];
        [[UIApplication sharedApplication].keyWindow insertSubview:self.showView belowSubview:lightView];
        
        [self.showView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@(kScreenHeight));
            make.height.equalTo(@(kScreenWidth));
            make.center.equalTo([[UIApplication sharedApplication].delegate window]);
        }];
        
        [lightView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo([UIApplication sharedApplication].keyWindow);
            make.centerY.equalTo([UIApplication sharedApplication].keyWindow);
            make.width.mas_equalTo(155);
            make.height.mas_equalTo(155);
        }];
    }
    
    _currentOrientation = orientation;
    
    [UIView animateWithDuration:0.5 animations:^{
        [[UIApplication sharedApplication] setStatusBarOrientation:_currentOrientation animated:YES];
        //旋转视频播放的view和显示亮度的view
        self.showView.transform = [self getOrientation:orientation];
        [NBLightView sharedInstance].transform = [self getOrientation:orientation];
    } completion:^(BOOL finished) {
        
    }];
}

//根据状态条旋转的方向来旋转 avplayerView
-(CGAffineTransform)getOrientation:(UIInterfaceOrientation)orientation {
    //    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (orientation == UIInterfaceOrientationPortrait) {
        [self toPortraitUpdate];
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft){
        [self toLandscapeUpdate];
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if (orientation == UIInterfaceOrientationLandscapeRight){
        [self toLandscapeUpdate];
        return CGAffineTransformMakeRotation(M_PI_2);
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        [self toPortraitUpdate];
        return CGAffineTransformMakeRotation(M_PI);
    }
    return CGAffineTransformIdentity;
}

-(void)toPortraitUpdate {
    _isFullScreen = NO;
    self.toolView.hidden = YES;
    //处理状态条
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    if ([UIApplication sharedApplication].statusBarHidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
}

-(void)toLandscapeUpdate {
    _isFullScreen = YES;
    
    //处理状态条
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    if (self.toolView.hidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }else{
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
}

#pragma mark - 对外的API

+ (void)clearAllVideoCache {
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp4"]) {
            NSString *absolutePath=[cachPath stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:absolutePath error:nil];
        }
    }
}

+ (double)allVideoCacheSize {
    
    double cacheVideoSize = 0.0f;
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp4"]) {
            NSString *path = [cachPath stringByAppendingPathComponent: fileName];
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath: path error: nil ];
            cacheVideoSize += ((double)([fileAttributes fileSize ]) / 1024.0 / 1024.0);
        }
    }
    
    return cacheVideoSize;
}

- (void)dealloc {
    NSLog(@"%@",@"NBVideoPlayer dealloc");
    [self.player pause];
    [self releasePlayer];
    [self unmonitoringPlayback];
}

@end
