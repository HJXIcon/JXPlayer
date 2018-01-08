//
//  UIView+WebVideoCache.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JXPlayerManager.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"

typedef NS_ENUM(NSInteger, JXPlayerVideoViewStatus) {
    JXPlayerVideoViewStatusPortrait,
    JXPlayerVideoViewStatusLandscape,
    JXPlayerVideoViewStatusAnimating
};

typedef void(^JXPlayerScreenAnimationCompletion)(void);

@protocol JXPlayerDelegate <NSObject>

@optional

- (BOOL)shouldDownloadVideoForURL:(nonnull NSURL *)videoURL;

- (BOOL)shouldAutoReplayAfterPlayCompleteForURL:(nonnull NSURL *)videoURL;

- (BOOL)shouldProgressViewOnTop;

- (BOOL)shouldDisplayBlackLayerBeforePlayStart;

- (void)playingStatusDidChanged:(JXPlayerPlayingStatus)playingStatus;

- (void)downloadingProgressDidChanged:(CGFloat)downloadingProgress;

- (void)playingProgressDidChanged:(CGFloat)playingProgress;

@end

@interface UIView (WebVideoCache)<JXPlayerManagerDelegate>

@property(nonatomic, nullable)id<JXPlayerDelegate> jx_videoPlayerDelegate;

@property(nonatomic, readonly)JXPlayerVideoViewStatus viewStatus;

@property(nonatomic, readonly)JXPlayerPlayingStatus playingStatus;


- (void)jx_playVideoWithURL:(nullable NSURL *)url;

- (void)jx_playVideoHiddenStatusViewWithURL:(nullable NSURL *)url;

- (void)jx_playVideoMutedHiddenStatusViewWithURL:(nullable NSURL *)url;

- (void)jx_playVideoMutedDisplayStatusViewWithURL:(nullable NSURL *)url;

- (void)jx_playVideoWithURL:(nullable NSURL *)url
                    options:(JXPlayerOptions)options
                   progress:(nullable JXPlayerDownloaderProgressBlock)progressBlock
                  completed:(nullable JXPlayerCompletionBlock)completedBlock;

#pragma mark -  *** Play Control

- (void)jx_stopPlay;

- (void)jx_pause;

- (void)jx_resume;

- (void)jx_setPlayerMute:(BOOL)mute;

- (BOOL)jx_playerIsMute;

#pragma mark - Landscape Or Portrait Control

- (void)jx_gotoLandscape;

- (void)jx_gotoLandscapeAnimated:(BOOL)animated completion:(JXPlayerScreenAnimationCompletion _Nullable)completion;

- (void)jx_gotoPortrait;

- (void)jx_gotoPortraitAnimated:(BOOL)animated completion:(JXPlayerScreenAnimationCompletion _Nullable)completion;

@end
