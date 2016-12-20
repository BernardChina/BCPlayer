//
//  NBTimeSheetView.m
//  namiboxVideo
//
//  Created by 刘勇强 on 16/12/2.
//  Copyright © 2016年 namibox. All rights reserved.
//

#import "NBTimeSheetView.h"
#import "NBPlayer.h"

@implementation NBTimeSheetView

- (instancetype)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:frame]) {
        
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        
        if (!_sheetStateImageView) {
            _sheetStateImageView = [[UIImageView alloc]init];
            _sheetStateImageView.contentMode = UIViewContentModeScaleAspectFit;
            [_sheetStateImageView setImage:[UIImage imageNamed:NBImageName(@"progress_icon_l")]];
            [self addSubview:_sheetStateImageView];
            [_sheetStateImageView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.mas_equalTo(12);
                make.width.mas_equalTo(43);
                make.height.mas_equalTo(25);
                make.centerX.equalTo(self);
            }];
        }
        
        if (!_sheetTimeLabel) {
            _sheetTimeLabel = [[UILabel alloc]init];
            _sheetTimeLabel.font = [UIFont systemFontOfSize:13];
            _sheetTimeLabel.textColor = [UIColor whiteColor];
            _sheetTimeLabel.textAlignment = NSTextAlignmentCenter;
            [self addSubview:_sheetTimeLabel];
            [_sheetTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(_sheetStateImageView.mas_bottom);
                make.width.mas_equalTo(118);
                make.height.mas_equalTo(20);
                make.centerX.equalTo(self);
            }];
        }
    }
    return self;
}

@end