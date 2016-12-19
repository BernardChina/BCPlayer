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
    
    NSArray *files = [temp sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return NSOrderedAscending;
    }];
    
    return files;
    
}

@end
