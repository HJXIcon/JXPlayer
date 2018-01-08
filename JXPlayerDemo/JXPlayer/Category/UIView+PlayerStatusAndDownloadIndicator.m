//
//  UIView+PlayerStatusAndDownloadIndicator.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import <objc/runtime.h>
#import "JXPlayerProgressView.h"
#import "JXPlayerActivityIndicator.h"
#import "UIView+WebVideoCache.h"
#import "JXPlayerPlayVideoTool.h"



@interface UIView ()

@property(nonatomic)JXPlayerProgressView *progressView;

@property(nonatomic)UIView *jx_videoLayerView;

@property(nonatomic)UIView *jx_indicatorView;

@property(nonatomic)UIColor *progressViewTintColor;

@property(nonatomic)UIColor *progressViewBackgroundColor;

@property(nonatomic)JXPlayerActivityIndicator *activityIndicatorView;

@end

static char progressViewKey;
static char progressViewTintColorKey;
static char progressViewBackgroundColorKey;
static char activityIndicatorViewKey;
static char videoLayerViewKey;
static char indicatorViewKey;
static char downloadProgressValueKey;
static char playingProgressValueKey;
static char backgroundLayerKey;


@implementation UIView (PlayerStatusAndDownloadIndicator)

#pragma mark - Properties

- (CALayer *)jx_backgroundLayer{
    CALayer *backLayer = objc_getAssociatedObject(self, &backgroundLayerKey);
    if (!backLayer) {
        backLayer = [CALayer new];
        backLayer.backgroundColor = [UIColor blackColor].CGColor;
        objc_setAssociatedObject(self, &backgroundLayerKey, backLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return backLayer;
}

- (void)setJx_playingProgressValue:(CGFloat)jx_playingProgressValue{
    objc_setAssociatedObject(self, &playingProgressValueKey, @(jx_playingProgressValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)jx_playingProgressValue{
    return [objc_getAssociatedObject(self, &playingProgressValueKey) floatValue];
}

- (void)setJx_downloadProgressValue:(CGFloat)jx_downloadProgressValue{
    objc_setAssociatedObject(self, &downloadProgressValueKey, @(jx_downloadProgressValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)jx_downloadProgressValue{
    return [objc_getAssociatedObject(self, &downloadProgressValueKey) floatValue];
}

- (void)setProgressViewTintColor:(UIColor *)progressViewTintColor{
    objc_setAssociatedObject(self, &progressViewTintColorKey, progressViewTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIColor *)progressViewTintColor{
    UIColor *color = objc_getAssociatedObject(self, &progressViewTintColorKey);
    if (!color) {
        color = [UIColor colorWithRed:0.0/255 green:118.0/255 blue:255.0/255 alpha:1];
    }
    return color;
}

- (void)setProgressViewBackgroundColor:(UIColor *)progressViewBackgroundColor{
    objc_setAssociatedObject(self, &progressViewBackgroundColorKey, progressViewBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIColor *)progressViewBackgroundColor{
    UIColor *color = objc_getAssociatedObject(self, &progressViewTintColorKey);
    if (!color) {
        color = [UIColor colorWithRed:155.0/255 green:155.0/255 blue:155.0/255 alpha:1.0];
    }
    return color;
}

- (JXPlayerProgressView *)progressView{
    JXPlayerProgressView *progressView = objc_getAssociatedObject(self, &progressViewKey);
    if (!progressView) {
        progressView = [JXPlayerProgressView new];
        progressView.hidden = YES;
        [self layoutProgressViewForPortrait:progressView];
        [progressView perfersDownloadProgressViewColor:self.progressViewBackgroundColor];
        [progressView perfersPlayingProgressViewColor:self.progressViewTintColor];
        progressView.backgroundColor = [UIColor clearColor];
        objc_setAssociatedObject(self, &progressViewKey, progressView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return progressView;
}

- (JXPlayerActivityIndicator *)activityIndicatorView{
    JXPlayerActivityIndicator *acv = objc_getAssociatedObject(self, &activityIndicatorViewKey);
    if (!acv) {
        acv = [JXPlayerActivityIndicator new];
        [self layoutActivityIndicatorViewForPortrait:acv];
        acv.hidden = YES;
        objc_setAssociatedObject(self, &activityIndicatorViewKey, acv, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return acv;
}

- (UIView *)jx_videoLayerView{
    UIView *view = objc_getAssociatedObject(self, &videoLayerViewKey);
    if (!view) {
        view = [UIView new];
        view.frame = self.bounds;
        view.backgroundColor = [UIColor clearColor];
        view.userInteractionEnabled = NO;
        objc_setAssociatedObject(self, &videoLayerViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}


- (UIView *)jx_indicatorView{
    UIView *view = objc_getAssociatedObject(self, &indicatorViewKey);
    if (!view) {
        view = [UIView new];
//        view.frame = self.bounds;
        view.backgroundColor = [UIColor clearColor];
        view.userInteractionEnabled = NO;
        objc_setAssociatedObject(self, &indicatorViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

- (void)jx_perfersPlayingProgressViewColor:(UIColor *)color{
    if (color) {
        [self.progressView perfersPlayingProgressViewColor:color];
        self.progressViewTintColor = color;
    }
}

- (void)jx_perfersDownloadProgressViewColor:(UIColor *)color{
    if (color) {
        [self.progressView perfersDownloadProgressViewColor:color];
        self.progressViewBackgroundColor = color;
    }
}


#pragma mark - Private

- (void)displayBackLayer{
    if (self.jx_backgroundLayer.superlayer) {
        return;
    }
    self.jx_backgroundLayer.frame = self.bounds;
    UIColor *backcolor = [UIColor clearColor];
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(shouldDisplayBlackLayerBeforePlayStart)]) {
        if ([self.jx_videoPlayerDelegate shouldDisplayBlackLayerBeforePlayStart]) {
            backcolor = [UIColor blackColor];
        }
    }
    self.jx_backgroundLayer.backgroundColor = backcolor.CGColor;
    [self.jx_videoLayerView.layer addSublayer:self.jx_backgroundLayer];
}

- (void)refreshIndicatorViewForPortrait{
    [self layoutProgressViewForPortrait:self.progressView];
    [self layoutActivityIndicatorViewForPortrait:self.activityIndicatorView];
    [self.progressView refreshProgressViewForScreenEvents];
}

- (void)refreshIndicatorViewForLandscape{
    [self layoutProgressViewForLandscape:self.progressView];
    [self layoutActivityIndicatorViewForLandscape:self.activityIndicatorView];
    [self.progressView refreshProgressViewForScreenEvents];
}

- (void)jx_showProgressView{
    if (!self.progressView.superview) {
        [self.jx_indicatorView addSubview:self.progressView];
        [self.progressView setDownloadProgress:0];
        [self.progressView setPlayingProgress:0];
        self.progressView.hidden = NO;
    }
}

- (void)jx_hideProgressView{
    if (self.progressView.superview) {
        self.progressView.hidden = YES;
        [self.progressView setDownloadProgress:0];
        [self.progressView setPlayingProgress:0];
        [self.progressView removeFromSuperview];
    }
}

- (void)jx_progressViewDownloadingStatusChangedWithProgressValue:(NSNumber *)progress{
    CGFloat delta = [progress floatValue];
    delta = MAX(0, delta);
    delta = MIN(delta, 1);
    [self.progressView setDownloadProgress:delta];
    self.jx_downloadProgressValue = delta;
}

- (void)jx_progressViewPlayingStatusChangedWithProgressValue:(NSNumber *)progress{
    CGFloat delta = [progress floatValue];
    delta = MAX(0, delta);
    delta = MIN(delta, 1);
    [self.progressView setPlayingProgress:delta];
    self.jx_playingProgressValue = delta;
}

- (void)jx_showActivityIndicatorView{
    if (!self.activityIndicatorView.superview) {
        [self.jx_indicatorView addSubview:self.activityIndicatorView];
        [self.activityIndicatorView startAnimating];
    }
}

- (void)jx_hideActivityIndicatorView{
    if (self.activityIndicatorView.superview) {
        [self.activityIndicatorView stopAnimating];
        [self.activityIndicatorView removeFromSuperview];
    }
}

- (void)jx_setupVideoLayerViewAndIndicatorView{
    if (!self.jx_videoLayerView.superview && !self.jx_indicatorView.superview) {
        [self addSubview:self.jx_videoLayerView];
        [self addSubview:self.jx_indicatorView];
        
    }
}

- (void)jx_removeVideoLayerViewAndIndicatorView{
    if (self.jx_videoLayerView.superview && self.jx_indicatorView.superview) {
        [self.jx_videoLayerView removeFromSuperview];
        [self.jx_indicatorView removeFromSuperview];
    }
}

#pragma mark - Landscape Events

- (void)layoutProgressViewForPortrait:(UIView *)progressView{
    CGFloat progressViewY = self.frame.size.height - JXPlayerLayerFrameY;
    if ([self.jx_videoPlayerDelegate respondsToSelector:@selector(shouldProgressViewOnTop)] && [self.jx_videoPlayerDelegate shouldProgressViewOnTop]) {
        progressViewY = 0;
    }
    progressView.frame = CGRectMake(0, progressViewY, self.frame.size.width, JXPlayerLayerFrameY);
}

- (void)layoutProgressViewForLandscape:(UIView *)progressView{
    CGFloat width = CGRectGetHeight(self.superview.bounds);
    CGFloat hei = CGRectGetWidth(self.superview.bounds);
    CGFloat progressViewY = hei - JXPlayerLayerFrameY;
    if ([self.jx_videoPlayerDelegate respondsToSelector:@selector(shouldProgressViewOnTop)] && [self.jx_videoPlayerDelegate shouldProgressViewOnTop]) {
        progressViewY = 0;
    }
    progressView.frame = CGRectMake(0, progressViewY, width, hei);
}

- (void)layoutActivityIndicatorViewForPortrait:(UIView *)acv{
    CGSize viewSize = self.frame.size;
    CGFloat selfX = (viewSize.width-JXPlayerActivityIndicatorWH)*0.5;
    CGFloat selfY = (viewSize.height-JXPlayerActivityIndicatorWH)*0.5;
    acv.frame = CGRectMake(selfX, selfY, JXPlayerActivityIndicatorWH, JXPlayerActivityIndicatorWH);
}

- (void)layoutActivityIndicatorViewForLandscape:(UIView *)acv{
    CGFloat width = CGRectGetHeight(self.superview.bounds);
    CGFloat hei = CGRectGetWidth(self.superview.bounds);
    CGFloat selfX = (width-JXPlayerActivityIndicatorWH)*0.5;
    CGFloat selfY = (hei-JXPlayerActivityIndicatorWH)*0.5;
    acv.frame = CGRectMake(selfX, selfY, JXPlayerActivityIndicatorWH, JXPlayerActivityIndicatorWH);
}

@end
