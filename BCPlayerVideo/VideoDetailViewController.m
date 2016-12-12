//
//  VideoDetailViewController.m
//
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import "VideoDetailViewController.h"
#import "BCPlayer.h"
#import <Masonry/Masonry.h>

@interface VideoDetailViewController () <BCPlayerDelegate>{
    BCVideoPlayer *_play;
}

@end

@implementation VideoDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    UIView *bgView = [[UIView alloc] init];
    bgView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:bgView];
    [bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view).offset(0);
    }];
    
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
             cacheType:NBPlayerCacheTypePlayHLS];
    
    NSLog(@"%f", [BCVideoPlayer allVideoCacheSize]);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
//    [_play stop];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)BCVideoPlayer:(BCVideoPlayer *)player withProgress:(double)progress currentTime:(double)current totalTime:(double)totalTime {

}

- (void)BCVideoPlayer:(BCVideoPlayer *)player didCompleteWithError:(NSError *)error {

}

- (void)NBVideoPlayer:(BCVideoPlayer *)player withProgress:(double)progress currentTime:(double)current totalTime:(double)totalTime {
    NSLog(@"当前：%f 总共：%f",current,totalTime);
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
