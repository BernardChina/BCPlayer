//
//  NBURLSessionDelegate.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NBURLSessionDelegate <NSObject>

- (void)didFinishLoading;
- (void)didFailLoadingwithError:(NSInteger )errorCode;

@end

