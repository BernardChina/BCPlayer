####BCPlayer
`BCPlayer`实现了几种播放模式。
- **边播边缓存** 
- **先缓存再播放** 
- **播放不缓存** 

除了基本的`mp4`并且支持`hls，m3u8`格式资源。
####安装
可以通过`CocoaPods`安装
在您的`Podfile`文件中添加
```
pod 'BCPlayer'
```
然后使用如下命令安装
```
pod install
```
或者
```
pod update
```

####用法
`BCPlayerDelegate`监听播放的进度和播放完成或者错误的回调
```
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
```
播放的类型
``` objectivec
typedef NS_ENUM(NSInteger, NBPlayerCacheType) {
    NBPlayerCacheTypeNoCache,       // 不缓存，直接播放
    NBPlayerCacheTypePlayWithCache, // 边播放边缓存
    NBPlayerCacheTypePlayAfterCache, // 先缓存，再播放
    NBPlayerCacheTypePlayHLS    // 支持hls
};
```
使用方法很简单：
``` objectivec
_play = [[BCVideoPlayer alloc]init];
    UIView *videoView = [[UIView alloc] init];
    [bgView addSubview:videoView];
    [videoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view).offset(0);
        make.top.equalTo(self.view).offset(64);
        make.height.equalTo(@(250));
    }];
    
    _play.delegate = self;
    
    [_play playWithUrl:[NSURL URLWithString:self.videoUrlStr]
              showView:videoView
          andSuperView:self.view
             cacheType:NBPlayerCacheTypePlayWithCache];
```

####TODO
未来也许会支持`编解码`。如果您有什么宝贵的意见或者问题，请您告诉我，感谢！一起做一款好的播放器

如果对您有帮助，请不要吝啬您的`star`，感谢！