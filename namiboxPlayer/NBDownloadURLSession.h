//
//  NBDownloadURLSession.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

@class M3U8SegmentInfo;
@interface NBDownloadURLSession : NSObject

@property (nonatomic, assign) double downloadProgress;
@property (nonatomic, assign) BOOL startPlay;
@property (nonatomic, strong) M3U8SegmentInfo *segmentInfo;

- (void)cancel;

- (void)addDownloadTask:(NSString *)playUrl;

@end
