//
//  NBPlayer.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#define NBImageName(file) [@"NBPlayer.bundle" stringByAppendingPathComponent:file]
#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)
#define kScreenWidth ([UIScreen mainScreen].bounds.size.width)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Masonry/Masonry.h>

#import "NBVideoPlayer.h"
#import "NBPlayerEnvironment.h"
#import "NSString+NB.h"
#import "NBPlayerDefine.h"
#import "NBPlayerDelegate.h"

