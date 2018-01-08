//
//  JXPlayerPlayVideoTool.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "JXPlayerManager.h"

extern CGFloat const JXPlayerLayerFrameY;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - *** JXPlayerPlayVideoToolItem
@interface JXPlayerPlayVideoToolItem : NSObject

@property(nonatomic, strong, readonly, nonnull)NSString *playingKey;

@property(nonatomic, strong, readonly, nullable)AVPlayerLayer *currentPlayerLayer;

@end


#pragma mark - *** JXPlayerPlayVideoTool
typedef NS_ENUM(NSInteger, JXPlayerPlayingToolStatus) {
    JXPlayerPlayingToolStatusUnkown,
    JXPlayerPlayingToolStatusBuffering,
    JXPlayerPlayingToolStatusPlaying,
    JXPlayerPlayingToolStatusPause,
    JXPlayerPlayingToolStatusFailed,
    JXPlayerPlayingToolStatusStop
};

typedef void(^JXPlayerPlayVideoToolErrorBlock)(NSError * _Nullable error);

typedef void(^JXPlayerPlayVideoToolPlayingProgressBlock)(CGFloat progress);

@class JXPlayerPlayVideoTool;

@protocol JXPlayerPlayVideoToolDelegate <NSObject>
@optional

- (BOOL)playVideoTool:(nonnull JXPlayerPlayVideoTool *)videoTool shouldAutoReplayVideoForURL:(nonnull NSURL *)videoURL;

- (void)playVideoTool:(nonnull JXPlayerPlayVideoTool *)videoTool playingStatuDidChanged:(JXPlayerPlayingToolStatus)playingStatus;

@end
/**
 负责视频播放的工具类
 */
@interface JXPlayerPlayVideoTool : NSObject

@property(nullable, nonatomic, weak)id<JXPlayerPlayVideoToolDelegate> delegate;

+ (nonnull instancetype)sharedTool;

@property(nonatomic, strong, readonly, nullable)JXPlayerPlayVideoToolItem *currentPlayVideoItem;


# pragma mark - Play video existed in disk.

- (nullable JXPlayerPlayVideoToolItem *)playExistedVideoWithURL:(NSURL * _Nullable)url fullVideoCachePath:(NSString * _Nullable)fullVideoCachePath options:(JXPlayerOptions)options showOnView:(UIView * _Nullable)showView playingProgress:(JXPlayerPlayVideoToolPlayingProgressBlock _Nullable )progress error:(nullable JXPlayerPlayVideoToolErrorBlock)error;


# pragma mark - Play video from Web.

- (nullable JXPlayerPlayVideoToolItem *)playVideoWithURL:(NSURL * _Nullable)url tempVideoCachePath:(NSString * _Nullable)tempVideoCachePath options:(JXPlayerOptions)options videoFileExceptSize:(NSUInteger)exceptSize videoFileReceivedSize:(NSUInteger)receivedSize showOnView:(UIView * _Nullable)showView playingProgress:(JXPlayerPlayVideoToolPlayingProgressBlock _Nullable )progress error:(nullable JXPlayerPlayVideoToolErrorBlock)error;

- (void)didReceivedDataCacheInDiskByTempPath:(NSString * _Nonnull)tempCacheVideoPath videoFileExceptSize:(NSUInteger)expectedSize videoFileReceivedSize:(NSUInteger)receivedSize;


- (void)didCachedVideoDataFinishedFromWebFullVideoCachePath:(NSString * _Nullable)fullVideoCachePath;


# pragma mark - Player Control Events


- (void)setMute:(BOOL)mute;

- (void)stopPlay;

- (void)pause;

- (void)resume;


@end

NS_ASSUME_NONNULL_END
