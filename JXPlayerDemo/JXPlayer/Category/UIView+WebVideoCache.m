//
//  UIView+WebVideoCache.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "UIView+WebVideoCache.h"
#import "UIView+WebVideoCacheOperation.h"
#import <objc/runtime.h>
#import "JXPlayerPlayVideoTool.h"
#import "JXPlayerCompat.h"


static NSString *JXPlayerErrorDomain = @"JXPlayerErrorDomain";

@interface UIView()
@property(nonatomic)UIView *parentView_beforeFullScreen;
@property(nonatomic)NSValue *frame_beforeFullScreen;

@end

@implementation UIView (WebVideoCache)

#pragma mark - setter/getter
- (void)setParentView_beforeFullScreen:(UIView *)parentView_beforeFullScreen{
    objc_setAssociatedObject(self, @selector(parentView_beforeFullScreen), parentView_beforeFullScreen, OBJC_ASSOCIATION_ASSIGN);
}

- (void)setPlayingStatus:(JXPlayerPlayingStatus)playingStatus{
    objc_setAssociatedObject(self, @selector(playingStatus), @(playingStatus), OBJC_ASSOCIATION_ASSIGN);
}

/**!
 _cmd在Objective-C的方法中表示当前方法的selector，正如同self表示当前方法调用的对象实例。
 而使用_cmd可以直接使用该@selector的名称，即someCategoryMethod，并且能保证改名称不重复
 http://www.jianshu.com/p/fdb1bc445266
 
 */

- (JXPlayerPlayingStatus)playingStatus{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (UIView *)parentView_beforeFullScreen{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setFrame_beforeFullScreen:(NSValue *)frame_beforeFullScreen{
    objc_setAssociatedObject(self, @selector(frame_beforeFullScreen), frame_beforeFullScreen, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSValue *)frame_beforeFullScreen{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setViewStatus:(JXPlayerVideoViewStatus)viewStatus{
    objc_setAssociatedObject(self, @selector(viewStatus), @(viewStatus), OBJC_ASSOCIATION_ASSIGN);
}

- (JXPlayerVideoViewStatus)viewStatus{
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (id<JXPlayerDelegate>)jx_videoPlayerDelegate{
    id (^__weak_block)(void) = objc_getAssociatedObject(self, _cmd);
    if (!__weak_block) {
        return nil;
    }
    return __weak_block();
}

- (void)setJx_videoPlayerDelegate:(id<JXPlayerDelegate>)jx_videoPlayerDelegate{
    id __weak __weak_object = jx_videoPlayerDelegate;
    id (^__weak_block)(void) = ^{
        return __weak_object;
    };
    objc_setAssociatedObject(self, @selector(jx_videoPlayerDelegate),   __weak_block, OBJC_ASSOCIATION_COPY);
}

#pragma mark - Play Video Methods

- (void)jx_playVideoWithURL:(NSURL *)url{
    [self jx_playVideoWithURL:url options:JXPlayerContinueInBackground | JXPlayerLayerVideoGravityResizeAspect | JXPlayerShowActivityIndicatorView | JXPlayerShowProgressView progress:nil completed:nil];
}

- (void)jx_playVideoHiddenStatusViewWithURL:(NSURL *)url{
    [self jx_playVideoWithURL:url options:JXPlayerContinueInBackground | JXPlayerShowActivityIndicatorView | JXPlayerLayerVideoGravityResizeAspect progress:nil completed:nil];
}

- (void)jx_playVideoMutedDisplayStatusViewWithURL:(NSURL *)url{
    [self jx_playVideoWithURL:url options:JXPlayerContinueInBackground | JXPlayerShowProgressView | JXPlayerShowActivityIndicatorView | JXPlayerLayerVideoGravityResizeAspect | JXPlayerMutedPlay progress:nil completed:nil];
}

- (void)jx_playVideoMutedHiddenStatusViewWithURL:(NSURL *)url{
    [self jx_playVideoWithURL:url options:JXPlayerContinueInBackground | JXPlayerMutedPlay | JXPlayerLayerVideoGravityResizeAspect | JXPlayerShowActivityIndicatorView progress:nil completed:nil];
}

- (void)jx_playVideoWithURL:(NSURL *)url options:(JXPlayerOptions)options progress:(JXPlayerDownloaderProgressBlock)progressBlock completed:(JXPlayerCompletionBlock)completedBlock{
    
    // 1.先取消
    NSString *validOperationKey = NSStringFromClass([self class]);
    [self jx_cancelVideoLoadOperationWithKey:validOperationKey];
    [self jx_stopPlay];
    self.currentPlayingURL = url;
    self.viewStatus = JXPlayerVideoViewStatusPortrait;
    
    // 2.开始
    if (url) {
        __weak typeof(self) wself = self;
        
        // set self as the delegate of `JXPlayerManager`.
        [JXPlayerManager sharedManager].delegate = self;
        
        // set up the video layer view and indicator view.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(@"jx_setupVideoLayerViewAndIndicatorView")];
#pragma clang diagnostic pop
    
        
        id <JXPlayerOperation> operation = [[JXPlayerManager sharedManager] loadVideoWithURL:url showOnView:self options:options progress:progressBlock completed:^(NSString * _Nullable fullVideoCachePath, NSError * _Nullable error, JXPlayerCacheType cacheType, NSURL * _Nullable videoURL) {
            __strong __typeof (wself) sself = wself;
            if (!sself) return;
            
            dispatch_main_async_safe(^{
                if (completedBlock) {
                    completedBlock(fullVideoCachePath, error, cacheType, url);
                }
            });
        }];
        
        [self jx_setVideoLoadOperation:operation forKey:validOperationKey];
    }
    else {
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:JXPlayerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, JXPlayerCacheTypeNone, url);
            }
        });
    }
}


#pragma mark - Play Control

- (void)jx_stopPlay{
    [[JXPlayerCache sharedCache] cancelCurrentComletionBlock];
    [[JXPlayerDownloader sharedDownloader] cancelAllDownloads];
    [[JXPlayerManager sharedManager]stopPlay];
}

- (void)jx_pause{
    [[JXPlayerManager sharedManager] pause];
}

- (void)jx_resume{
    [[JXPlayerManager sharedManager] resume];
}

- (void)jx_setPlayerMute:(BOOL)mute{
    [[JXPlayerManager sharedManager] setPlayerMute:mute];
}

- (BOOL)jx_playerIsMute{
    return [JXPlayerManager sharedManager].playerIsMute;
}


#pragma mark - Landscape Or Portrait Control

- (void)jx_gotoLandscape {
    [self jx_gotoLandscapeAnimated:YES completion:nil];
}

- (void)jx_gotoLandscapeAnimated:(BOOL)animated completion:(JXPlayerScreenAnimationCompletion)completion {
    if (self.viewStatus != JXPlayerVideoViewStatusPortrait) {
        return;
    }
    
    self.jx_videoLayerView.backgroundColor = [UIColor blackColor];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // hide status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    
    self.viewStatus = JXPlayerVideoViewStatusAnimating;
    
    self.parentView_beforeFullScreen = self.superview;
    self.frame_beforeFullScreen = [NSValue valueWithCGRect:self.frame];
    
    CGRect rectInWindow = [self.superview convertRect:self.frame toView:nil];
    [self removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    self.frame = rectInWindow;
    self.jx_indicatorView.alpha = 0;
    
    if (animated) {
        [UIView animateWithDuration:0.35 animations:^{
            
            [self executeLandscape];
            
        } completion:^(BOOL finished) {
            
            self.viewStatus = JXPlayerVideoViewStatusLandscape;
            if (completion) {
                completion();
            }
            [UIView animateWithDuration:0.5 animations:^{
                
                self.jx_indicatorView.alpha = 1;
            }];
            
        }];
    }
    else{
        [self executeLandscape];
        self.viewStatus = JXPlayerVideoViewStatusLandscape;
        if (completion) {
            completion();
        }
        [UIView animateWithDuration:0.5 animations:^{
            
            self.jx_indicatorView.alpha = 1;
        }];
    }
    
    [self refreshStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
}

- (void)jx_gotoPortrait {
    [self jx_gotoPortraitAnimated:YES completion:nil];
}

- (void)jx_gotoPortraitAnimated:(BOOL)animated completion:(JXPlayerScreenAnimationCompletion)completion{
    if (self.viewStatus != JXPlayerVideoViewStatusLandscape) {
        return;
    }
    
    self.jx_videoLayerView.backgroundColor = [UIColor clearColor];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // display status bar.
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    
    self.viewStatus = JXPlayerVideoViewStatusAnimating;
    
    self.jx_indicatorView.alpha = 0;
    
    if (animated) {
        [UIView animateWithDuration:0.35 animations:^{
            
            [self executePortrait];
            
        } completion:^(BOOL finished) {
            
            [self finishPortrait];
            if (completion) {
                completion();
            }
            
        }];
    }
    else{
        [self executePortrait];
        [self finishPortrait];
        if (completion) {
            completion();
        }
    }
    
    [self refreshStatusBarOrientation:UIInterfaceOrientationPortrait];
}


#pragma mark - Private

- (void)finishPortrait{
    [self removeFromSuperview];
    [self.parentView_beforeFullScreen addSubview:self];
    self.frame = [self.frame_beforeFullScreen CGRectValue];
    
    self.jx_backgroundLayer.frame = self.bounds;
    [JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = self.bounds;
    self.jx_videoLayerView.frame = self.bounds;
    self.jx_indicatorView.frame = self.bounds;
    
    self.viewStatus = JXPlayerVideoViewStatusPortrait;
    
    [UIView animateWithDuration:0.5 animations:^{
        
        self.jx_indicatorView.alpha = 1;
    }];
}

- (void)executePortrait{
    CGRect frame = [self.parentView_beforeFullScreen convertRect:[self.frame_beforeFullScreen CGRectValue] toView:nil];
    self.transform = CGAffineTransformIdentity;
    self.frame = frame;
    
    self.jx_backgroundLayer.frame = self.bounds;
    [JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = self.bounds;
    self.jx_videoLayerView.frame = self.bounds;
    self.jx_indicatorView.frame = self.bounds;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForPortrait")];
#pragma clang diagnostic pop
}

- (void)executeLandscape{
    self.transform = CGAffineTransformMakeRotation(M_PI_2);
    CGRect bounds = CGRectMake(0, 0, CGRectGetHeight(self.superview.bounds), CGRectGetWidth(self.superview.bounds));
    CGPoint center = CGPointMake(CGRectGetMidX(self.superview.bounds), CGRectGetMidY(self.superview.bounds));
    self.bounds = bounds;
    self.center = center;
    
    self.jx_backgroundLayer.frame = bounds;
    [JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem.currentPlayerLayer.frame = bounds;
    self.jx_videoLayerView.frame = bounds;
    self.jx_indicatorView.frame = bounds;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"refreshIndicatorViewForLandscape")];
#pragma clang diagnostic pop
}

- (void)refreshStatusBarOrientation:(UIInterfaceOrientation)interfaceOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:YES];
#pragma clang diagnostic pop
}



#pragma mark - JXPlayerManager

- (BOOL)videoPlayerManager:(JXPlayerManager *)videoPlayerManager shouldDownloadVideoForURL:(NSURL *)videoURL{
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(shouldDownloadVideoForURL:)]) {
        return [self.jx_videoPlayerDelegate shouldDownloadVideoForURL:videoURL];
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JXPlayerManager *)videoPlayerManager shouldAutoReplayForURL:(NSURL *)videoURL{
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(shouldAutoReplayAfterPlayCompleteForURL:)]) {
        return [self.jx_videoPlayerDelegate shouldAutoReplayAfterPlayCompleteForURL:videoURL];
    }
    return YES;
}

- (void)videoPlayerManager:(JXPlayerManager *)videoPlayerManager playingStatusDidChanged:(JXPlayerPlayingStatus)playingStatus{
    self.playingStatus = playingStatus;
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(playingStatusDidChanged:)]) {
        [self.jx_videoPlayerDelegate playingStatusDidChanged:playingStatus];
    }
}

- (BOOL)videoPlayerManager:(JXPlayerManager *)videoPlayerManager downloadingProgressDidChanged:(CGFloat)downloadingProgress{
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(downloadingProgressDidChanged:)]) {
        [self.jx_videoPlayerDelegate downloadingProgressDidChanged:downloadingProgress];
        return NO;
    }
    return YES;
}

- (BOOL)videoPlayerManager:(JXPlayerManager *)videoPlayerManager playingProgressDidChanged:(CGFloat)playingProgress{
    if (self.jx_videoPlayerDelegate && [self.jx_videoPlayerDelegate respondsToSelector:@selector(playingProgressDidChanged:)]) {
        [self.jx_videoPlayerDelegate playingProgressDidChanged:playingProgress];
        return NO;
    }
    return YES;
}

@end
