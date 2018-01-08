//
//  JXPlayerManger.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JXPlayerOperation.h"
#import "JXPlayerCache.h"
#import "JXPlayerDownloader.h"
/**!
 02.JPVideoPlayerManager 负责甄别用户传过来的 URL，根据不同的 URL 作出不同的反应进行视频播放。具体细节如下：
 
 02.1、是否是本地文件路径，如果是本地路径，直接把路径给负责视频播放的工具类 JPVideoPlayerPlayVideoTool 进行视频播放；
 
 02.2、如果不是本地路径，再根据 URL 生成缓存的 key 给 JPVideoPlayerCache 工具类查找是否有本地缓存文件，如果有缓存就把缓存路径返还给JPVideoPlayerManager，JPVideoPlayerManager 会把路径给负责视频播放的工具类 JPVideoPlayerPlayVideoTool 进行视频播放；
 
 02.3、如果没有本地缓存，就把 URL 给 JPVideoPlayerDownloader 下载工具类，这个工具类就会去网络上下载视频数据，每下载完一段数据，都会返回给 JPVideoPlayerManager，JPVideoPlayerManager 会先把这段数据给 JPVideoPlayerCache， JPVideoPlayerCache 先把数据缓存到磁盘，然后再把缓存的路径返还给JPVideoPlayerManager，JPVideoPlayerManager 会把路径给负责视频播放的工具类 JPVideoPlayerPlayVideoTool 进行视频播放。
 
 */

typedef NS_OPTIONS(NSUInteger, JXPlayerOptions) {
    
    JXPlayerRetryFailed = 1 << 0,
    
    JXPlayerContinueInBackground = 1 << 1,
    
    JXPlayerHandleCookies = 1 << 2,

    JXPlayerAllowInvalidSSLCertificates = 1 << 3,
    
    JXPlayerShowProgressView = 1 << 4,
    
    JXPlayerShowActivityIndicatorView = 1 << 5,
    
    JXPlayerMutedPlay = 1 << 6,
    
    JXPlayerLayerVideoGravityResize = 1 << 7,
    
    JXPlayerLayerVideoGravityResizeAspect = 1 << 8,
    
    JXPlayerLayerVideoGravityResizeAspectFill = 1 << 9,
};

typedef NS_ENUM(NSInteger, JXPlayerPlayingStatus) {
    JXPlayerPlayingStatusUnkown,
    JXPlayerPlayingStatusBuffering,
    JXPlayerPlayingStatusPlaying,
    JXPlayerPlayingStatusPause,
    JXPlayerPlayingStatusFailed,
    JXPlayerPlayingStatusStop
};

typedef void(^JXPlayerCompletionBlock)(NSString * _Nullable fullVideoCachePath, NSError * _Nullable error, JXPlayerCacheType cacheType, NSURL * _Nullable videoURL);

@class JXPlayerManager;

@protocol JXPlayerManagerDelegate <NSObject>

@optional

- (BOOL)videoPlayerManager:(nonnull JXPlayerManager *)videoPlayerManager shouldDownloadVideoForURL:(nullable NSURL *)videoURL;

- (BOOL)videoPlayerManager:(nonnull JXPlayerManager *)videoPlayerManager shouldAutoReplayForURL:(nullable NSURL *)videoURL;

- (void)videoPlayerManager:(nonnull JXPlayerManager *)videoPlayerManager playingStatusDidChanged:(JXPlayerPlayingStatus)playingStatus;

- (BOOL)videoPlayerManager:(nonnull JXPlayerManager *)videoPlayerManager downloadingProgressDidChanged:(CGFloat)downloadingProgress;


- (BOOL)videoPlayerManager:(nonnull JXPlayerManager *)videoPlayerManager playingProgressDidChanged:(CGFloat)playingProgress;

@end

/**
 管理者，协调各个模块相互配合工作
 */
@interface JXPlayerManager : NSObject
@property (weak, nonatomic, nullable) id <JXPlayerManagerDelegate> delegate;

@property (strong, nonatomic, readonly, nullable) JXPlayerCache *videoCache;

@property (strong, nonatomic, readonly, nullable) JXPlayerDownloader *videoDownloader;

#pragma mark - Singleton and initialization

+ (nonnull instancetype)sharedManager;

- (nonnull instancetype)initWithCache:(nonnull JXPlayerCache *)cache downloader:(nonnull JXPlayerDownloader *)downloader NS_DESIGNATED_INITIALIZER;


# pragma mark - Video Data Load And Play Video Options
- (nullable id <JXPlayerOperation>)loadVideoWithURL:(nullable NSURL *)url showOnView:(nullable UIView *)showView options:(JXPlayerOptions)options progress:(nullable JXPlayerDownloaderProgressBlock)progressBlock completed:(nullable JXPlayerCompletionBlock)completedBlock;

- (void)cancelAllDownloads;

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url;


# pragma mark - Play Control

- (void)stopPlay;

- (void)pause;

- (void)resume;

- (void)setPlayerMute:(BOOL)mute;

- (BOOL)playerIsMute;

@end
