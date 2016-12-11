//
//  BCPlayer.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#define NBImageName(file) [@"BCPlayer.bundle" stringByAppendingPathComponent:file]
#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)
#define kScreenWidth ([UIScreen mainScreen].bounds.size.width)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Masonry/Masonry.h>

#import "BCVideoPlayer.h"
#import "BCPlayerEnvironment.h"
#import "NSString+BC.h"
#import "BCPlayerDefine.h"
#import "BCPlayerDelegate.h"

