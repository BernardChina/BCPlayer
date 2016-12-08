//
//  VideoDetailViewController.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "VideoDetailViewController.h"
#import "NBPlayer.h"

@interface VideoDetailViewController (){
    NBVideoPlayer *_play;
}

@end

@implementation VideoDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.backBarButtonItem.title = @"";
    // Do any additional setup after loading the view, typically from a nib.
    
    
    _play = [[NBVideoPlayer alloc]init];
    UIView *videoView = [[UIView alloc]initWithFrame:CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * 0.5625)];
    [self.view addSubview:videoView];
    
    [_play playWithUrl:[NSURL URLWithString:self.videoUrlStr]
              showView:videoView
          andSuperView:self.view
             cacheType:NBPlayerCacheTypePlayHLS];
    
    NSLog(@"%f", [NBVideoPlayer allVideoCacheSize]);
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



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
