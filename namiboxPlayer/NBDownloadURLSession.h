//
//  NBDownloadURLSession.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBURLSessionDelegate.h"

@interface NBDownloadURLSession : NSObject

// 视频播放地址
@property (nonatomic, copy) NSString *playUrl;
@property (nonatomic, weak) id<NBURLSessionDelegate> delegate;

@end
