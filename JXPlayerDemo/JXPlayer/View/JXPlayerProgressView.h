//
//  JXPlayerProgressView.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JXPlayerProgressView : UIView

@property(nonatomic, assign, readonly)CGFloat downloadProgressValue;


@property(nonatomic, assign, readonly)CGFloat playingProgressValue;

- (void)setDownloadProgress:(CGFloat)downloadProgress;

- (void)setPlayingProgress:(CGFloat)playingProgress;


- (void)perfersDownloadProgressViewColor:(UIColor * _Nonnull)color;

- (void)perfersPlayingProgressViewColor:(UIColor * _Nonnull)color;

- (void)refreshProgressViewForScreenEvents;

@end
