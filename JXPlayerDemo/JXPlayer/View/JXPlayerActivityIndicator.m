//
//  JXPlayerActivityIndicator.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerActivityIndicator.h"

CGFloat const JXPlayerActivityIndicatorWH = 46;

@interface JXPlayerActivityIndicator()

@property(nonatomic, strong, nullable)UIActivityIndicatorView *activityIndicator;

@property(nonatomic, strong, nullable)UIVisualEffectView *blurView;

@property(nonatomic, assign, getter=isAnimating)BOOL animating;

@end

@implementation JXPlayerActivityIndicator
- (instancetype)init{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    self.blurView.frame = self.bounds;
    self.activityIndicator.frame = self.bounds;
}

- (void)setup{
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 8;
    self.clipsToBounds = YES;
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    [self addSubview:blurView];
    self.blurView = blurView;
    
    UIActivityIndicatorView *indicator = [UIActivityIndicatorView new];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    indicator.color = [UIColor colorWithRed:35.0/255 green:35.0/255 blue:35.0/255 alpha:1];
    [self addSubview:indicator];
    self.activityIndicator = indicator;
    
    self.animating = NO;
}


- (void)startAnimating{
    if (!self.isAnimating) {
        self.hidden = NO;
        [self.activityIndicator startAnimating];
        self.animating = YES;
    }
}

- (void)stopAnimating{
    if (self.isAnimating) {
        self.hidden = YES;
        [self.activityIndicator stopAnimating];
        self.animating = NO;
    }
}




@end
