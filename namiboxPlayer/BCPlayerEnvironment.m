//
//  BCPlayerEnvironment.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import "BCPlayerEnvironment.h"

static BCPlayerEnvironment *_env;

void NBSetWBEnviroment(BCPlayerEnvironment *env) {
    _env = env;
}

@interface BCPlayerEnvironment()

@end

@implementation BCPlayerEnvironment

+ (instancetype)defaultEnvironment {
    if (!_env) {
        _env = [BCPlayerEnvironment new];
    }
    return _env;
}

- (NSString *)cachePath {
    //这里自己写需要保存数据的路径
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    return document;
}

@end
