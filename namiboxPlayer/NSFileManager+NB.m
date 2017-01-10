//
//  NSFileManager+NB.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/17.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NSFileManager+NB.h"

@implementation NSFileManager (NB)

- (NSArray *)getFilesWithSuffix:(NSString *)suffix path:(NSString *)path {
    NSError *error = nil;
    NSArray *fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    NSMutableArray *temp = [[NSMutableArray alloc] init];
    
    [fileList enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([[obj pathExtension] isEqualToString:suffix]) {
            [temp addObject:obj];
        }
    }];
    
    NSArray *files = [temp sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1,NSString *obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    
    return files;
    
}

- (NSString *)getLastFileNameWithSuffix:(NSString *)suffix path:(NSString *)path {
    NSArray *files = [self getFilesWithSuffix:suffix path:path];
    
    return [files.lastObject stringByDeletingPathExtension];
}

- (BOOL)haveDownloaded:(NSString *)fileName withPath:(NSString *)path {
    NSArray *files = [self getFilesWithSuffix:@"ts" path:path];
    __block BOOL downloaded = NO;
    [files enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqualToString:fileName]) {
            downloaded = YES;
        }
    }];
    
    return downloaded;
}

@end
