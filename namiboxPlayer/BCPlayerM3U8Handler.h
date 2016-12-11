//
//  BCPlayerM3U8Handler.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/8.
//  Copyright © 2016年 BernardChina. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BCDownloadURLSession.h"

@interface M3U8SegmentInfo : NSObject

@property(nonatomic,assign) NSInteger duration;
@property(nonatomic,copy) NSString* locationUrl;

@end

typedef void(^praseFailed)(NSError *error);

@interface BCPlayerM3U8Handler : NSObject

@property (nonatomic, strong) BCDownloadURLSession *loadSession;
@property (nonatomic, strong) praseFailed praseFailed;

/**
 解析M3U8格式文件

 @param urlstr M3U8视频地址
 */
-(void)praseUrl:(NSString*)urlstr;

@end
