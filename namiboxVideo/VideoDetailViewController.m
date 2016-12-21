//
//  VideoDetailViewController.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "VideoDetailViewController.h"
#import "NBPlayer.h"
#import <Masonry/Masonry.h>

@interface VideoDetailViewController () <NBPlayerDelegate>{
    NBVideoPlayer *_play;
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
    
    _play = [[NBVideoPlayer alloc]init];
    UIView *videoView = [[UIView alloc]initWithFrame:CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * 0.5625)];
    [bgView addSubview:videoView];
    
    _play.delegate = self;
    
    [_play playWithUrl:[NSURL URLWithString:self.videoUrlStr]
              showView:videoView
          andSuperView:self.view
             cacheType:NBPlayerCacheTypePlayWithCache];
    
    NSLog(@"%f", [NBVideoPlayer allVideoCacheSize]);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_play stop];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)NBVideoPlayer:(NBVideoPlayer *)player withProgress:(double)progress currentTime:(double)current totalTime:(double)totalTime {
    NSLog(@"当前：%f 总共：%f",current,totalTime);
}

- (void)NBVideoPlayer:(NBVideoPlayer *)player didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"%@",error);
    }
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
