//
//  NBPlayerView.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@implementation NBPlayerView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

@end
