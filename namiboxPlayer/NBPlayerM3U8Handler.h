//
//  NBPlayerM3U8Handler.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/8.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "NBDownloadURLSession.h"

@interface M3U8SegmentInfo : NSObject

@property(nonatomic,assign) double duration;
@property(nonatomic,copy) NSString *locationUrl;

@end

typedef void(^praseFailed)(NSError *error, NSInteger nextTs);
typedef void(^playFinished)(void);

@interface NBPlayerM3U8Handler : NSObject

@property (nonatomic, strong) NBDownloadURLSession *loadSession;
@property (nonatomic, strong) praseFailed praseFailed;
@property (nonatomic, strong) playFinished playFinished;

/**
 解析M3U8格式文件

 @param urlstr M3U8视频地址
 */
-(void)praseUrl:(NSString*)urlstr;

-(void)refreshTask:(NSInteger)textTs completeWithError:(praseFailed)error;

@end
