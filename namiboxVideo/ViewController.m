//
//  ViewController.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "ViewController.h"
#import "VideoDetailViewController.h"

#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)
#define kScreenWidth ([UIScreen mainScreen].bounds.size.width)

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *videoList;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *homedi = NSHomeDirectory();
    
    NSLog(@"app path :%@",homedi);
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"纳米盒子播放器";
    
    [self.videoList addObject:@"http://baobab.wdjcdn.com/14571455324031.mp4"];
    [self.videoList addObject:@"http://baobab.wdjcdn.com/14564977406580.mp4"];
    
    //    [self.videoList addObject:@"http://baobab.wdjcdn.com/1457716884751linghunbanlv_x264.mp4"];
    [self.videoList addObject:@"http://baobab.wdjcdn.com/14587897797934.mp4"];
    
    [self.view addSubview:self.tableView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 初始化控件

- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight - 64) style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    }
    return _tableView;
}

- (NSMutableArray *)videoList {
    if (!_videoList) {
        _videoList = [[NSMutableArray alloc]init];
    }
    return _videoList;
}

#pragma mark - UITableView M

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.videoList count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"视频%ld", (long)indexPath.row + 1];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    VideoDetailViewController *videoVC = [[VideoDetailViewController alloc]init];
    videoVC.videoUrlStr = [self.videoList objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:videoVC animated:YES];
}


@end
