//
//  NBPlayerDelegate.h
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/6.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBVideoPlayer.h"

@class NBVideoPlayer;
@protocol NBPlayerDelegate <NSObject>

- (void)NBVideoPlayer:(NBVideoPlayer *)player didCompleteWithError:(NSError *)error;
- (void)NBVideoPlayer:(NBVideoPlayer *)player withProgress:(double)progress;

@end
