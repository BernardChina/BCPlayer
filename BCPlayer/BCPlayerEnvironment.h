//
//  BCPlayerEnvironment.h
//  
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BCPlayerEnvironment;

void BCSetWBEnviroment(BCPlayerEnvironment *env);

@interface BCPlayerEnvironment : NSObject

+ (instancetype)defaultEnvironment;


/**
 保存视频缓存文件路径

 @return 保存视频缓存文件路径
 */
- (NSString *)cachePath;

@end
