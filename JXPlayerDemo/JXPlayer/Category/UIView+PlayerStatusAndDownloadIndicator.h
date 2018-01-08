//
//  UIView+PlayerStatusAndDownloadIndicator.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (PlayerStatusAndDownloadIndicator)

@property(nonatomic, readonly, nullable)UIView *jx_videoLayerView;

@property(nonatomic, readonly, nullable)CALayer *jx_backgroundLayer;

@property(nonatomic, readonly, nullable)UIView *jx_indicatorView;

@property(nonatomic, readonly)CGFloat jx_downloadProgressValue;

@property(nonatomic, readonly)CGFloat jx_playingProgressValue;

- (void)jx_perfersDownloadProgressViewColor:(UIColor * _Nonnull)color;

- (void)jx_perfersPlayingProgressViewColor:(UIColor * _Nonnull)color;


@end
