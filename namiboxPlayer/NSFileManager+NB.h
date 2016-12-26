//
//  NSFileManager+NB.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/17.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (NB)

/**
 获取某后缀名的文件，最后一个文件

 @param suffix 后缀名
 @param path 文件夹
 */
- (NSArray *)getFilesWithSuffix:(NSString *)suffix path:(NSString *)path;


/**
 获取最后一个文件的文件名

 @param suffix 后缀名
 @param path 文件路径
 @return 文件名
 */
- (NSString *)getLastFileNameWithSuffix:(NSString *)suffix path:(NSString *)path;

@end
