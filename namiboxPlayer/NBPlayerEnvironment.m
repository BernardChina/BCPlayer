//
//  NBPlayerEnvironment.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBPlayerEnvironment.h"

static NBPlayerEnvironment *_env;

void NBSetWBEnviroment(NBPlayerEnvironment *env) {
    _env = env;
}

@interface NBPlayerEnvironment()

@end

@implementation NBPlayerEnvironment

+ (instancetype)defaultEnvironment {
    if (!_env) {
        _env = [NBPlayerEnvironment new];
    }
    return _env;
}

- (NSString *)cachePath {
    //这里自己写需要保存数据的路径
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString *path = [document stringByAppendingString:@"/videos"];
    BOOL isDir;
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (!(isExist && isDir)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

@end
