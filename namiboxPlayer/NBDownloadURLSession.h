//
//  NBDownloadURLSession.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/5.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBDownloadURLSession : NSObject

//- (instancetype) initWidthPlayUrl:(NSString *)playUrl;

@property (nonatomic, assign) double downloadProgress;
@property (nonatomic, assign) BOOL startPlay;

- (void)cancel;

- (void)addDownloadTask:(NSString *)playUrl;

@end
