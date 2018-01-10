//
//  JXPlayerPlayVideoTool.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerPlayVideoTool.h"
#import "JXPlayerResourceLoader.h"
#import "UIView+PlayerStatusAndDownloadIndicator.h"
#import "UIView+WebVideoCache.h"
#import "JXPlayerDownloaderOperation.h"
#import "JXPlayerCompat.h"


CGFloat const JXPlayerLayerFrameY = 1;


#pragma mark - *** JXPlayerPlayVideoToolItem
@interface JXPlayerPlayVideoToolItem()

@property(nonatomic, strong, nullable)NSURL *url;

@property(nonatomic, strong, nullable)AVPlayer *player;

@property(nonatomic, strong, nullable)AVPlayerLayer *currentPlayerLayer;

@property(nonatomic, strong, nullable)AVPlayerItem *currentPlayerItem;

@property(nonatomic, strong, nullable)AVURLAsset *videoURLAsset;

@property(nonatomic, weak, nullable)UIView *unownShowView;

@property(nonatomic, assign, getter=isCancelled)BOOL cancelled;


@property(nonatomic, copy, nullable)JXPlayerPlayVideoToolErrorBlock error;

@property(nonatomic, strong, nullable)JXPlayerResourceLoader *resourceLoader;

@property(nonatomic, assign)JXPlayerOptions playerOptions;


@property(nonatomic, strong, nonnull)NSString *playingKey;

@property(nonatomic, assign)NSTimeInterval lastTime;


@property(nonatomic, strong)id timeObserver;

@end

static NSString *JXPlayerURLScheme = @"SystemCannotRecognition.icon";
static NSString *JXPlayerURL = @"www.HJXIcon.com";


@implementation JXPlayerPlayVideoToolItem

- (void)stopPlayVideo{
    self.cancelled = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.unownShowView performSelector:NSSelectorFromString(@"jx_hideProgressView")];
    [self.unownShowView performSelector:NSSelectorFromString(@"jx_hideActivityIndicatorView")];
    #pragma clang diagnostic pop
    
    [self reset];
}


- (void)pausePlayVideo{
    if (!self.player) {
        return;
    }
    [self.player pause];
}

- (void)resumePlayVideo{
    if (!self.player) {
        return;
    }
    [self.player play];
}

- (void)reset{
    // remove video layer from superlayer.
    if (self.unownShowView.jx_backgroundLayer.superlayer) {
        [self.currentPlayerLayer removeFromSuperlayer];
        [self.unownShowView.jx_backgroundLayer removeFromSuperlayer];
    }
    
    // remove observer.
    JXPlayerPlayVideoTool *tool = [JXPlayerPlayVideoTool sharedTool];
    [_currentPlayerItem removeObserver:tool forKeyPath:@"status"];
    [_currentPlayerItem removeObserver:tool forKeyPath:@"loadedTimeRanges"];
    [self.player removeTimeObserver:self.timeObserver];
    
    // remove player
    [self.player pause];
    [self.player cancelPendingPrerolls];
    self.player = nil;
    [self.videoURLAsset.resourceLoader setDelegate:nil queue:dispatch_get_main_queue()];
    self.currentPlayerItem = nil;
    self.currentPlayerLayer = nil;
    self.videoURLAsset = nil;
    self.resourceLoader = nil;
}

@end


#pragma mark - *** JXPlayerPlayVideoTool
@interface JXPlayerPlayVideoTool()

@property(nonatomic, strong, nonnull)NSMutableArray<JXPlayerPlayVideoToolItem *> *playVideoItems;
@property(nonatomic, assign)JXPlayerPlayingStatus playingStatus_beforeEnterBackground;

@end

@implementation JXPlayerPlayVideoTool


+ (nonnull instancetype)sharedTool{
    static dispatch_once_t onceItem;
    static id instance;
    dispatch_once(&onceItem, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [self addObserverOnce];
        _playVideoItems = [NSMutableArray array];
    }
    return self;
}


#pragma mark - Public

- (nullable JXPlayerPlayVideoToolItem *)playExistedVideoWithURL:(NSURL * _Nullable)url
                                             fullVideoCachePath:(NSString * _Nullable)fullVideoCachePath
                                                        options:(JXPlayerOptions)options
                                                     showOnView:(UIView * _Nullable)showView
                                                playingProgress:(JXPlayerPlayVideoToolPlayingProgressBlock _Nullable )progress
                                                          error:(nullable JXPlayerPlayVideoToolErrorBlock)error{
    
    if (fullVideoCachePath.length==0) {
        if (error) error([NSError errorWithDomain:@"the file path is disable" code:0 userInfo:nil]);
        return nil;
    }
    
    if (!showView) {
        if (error) error([NSError errorWithDomain:@"the layer to display video layer is nil" code:0 userInfo:nil]);
        return nil;
    }
    
    JXPlayerPlayVideoToolItem *item = [JXPlayerPlayVideoToolItem new];
    item.unownShowView = showView;
    NSURL *videoPathURL = [NSURL fileURLWithPath:fullVideoCachePath];
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:videoPathURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    {
        item.url = url;
        item.currentPlayerItem = playerItem;
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        
        item.player = [AVPlayer playerWithPlayerItem:playerItem];
        item.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:item.player];
        {
            NSString *videoGravity = nil;
            if (options&JXPlayerLayerVideoGravityResizeAspect) {
                videoGravity = AVLayerVideoGravityResizeAspect;
            }
            else if (options&JXPlayerLayerVideoGravityResize){
                videoGravity = AVLayerVideoGravityResize;
            }
            else if (options&JXPlayerLayerVideoGravityResizeAspectFill){
                videoGravity = AVLayerVideoGravityResizeAspectFill;
            }
            item.currentPlayerLayer.videoGravity = videoGravity;
        }
        
        item.unownShowView.jx_backgroundLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
        item.currentPlayerLayer.frame = item.unownShowView.jx_backgroundLayer.bounds;
        
        
        item.error = error;
        item.playingKey = [[JXPlayerManager sharedManager]cacheKeyForURL:url];
    }
    {
        // add observer for video playing progress.
        __weak typeof(item) wItem = item;
        [item.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 10.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time){
            __strong typeof(wItem) sItem = wItem;
            if (!sItem) return;
            
            float current = CMTimeGetSeconds(time);
            float total = CMTimeGetSeconds(sItem.currentPlayerItem.duration);
            if (current && progress) {
                progress(current / total);
            }
        }];
    }
    
    if (options & JXPlayerMutedPlay) {
        item.player.muted = YES;
    }
    
    @synchronized (self) {
        [self.playVideoItems addObject:item];
    }
    self.currentPlayVideoItem = item;
    
    return item;
}

- (nullable JXPlayerPlayVideoToolItem *)playVideoWithURL:(NSURL * _Nullable)url tempVideoCachePath:(NSString * _Nullable)tempVideoCachePath options:(JXPlayerOptions)options videoFileExceptSize:(NSUInteger)exceptSize videoFileReceivedSize:(NSUInteger)receivedSize showOnView:(UIView * _Nullable)showView playingProgress:(JXPlayerPlayVideoToolPlayingProgressBlock _Nullable )progress error:(nullable JXPlayerPlayVideoToolErrorBlock)error{
    
    if (tempVideoCachePath.length==0) {
        if (error) error([NSError errorWithDomain:@"the file path is disable" code:0 userInfo:nil]);
        return nil;
    }
    
    if (!showView) {
        if (error) error([NSError errorWithDomain:@"the layer to display video layer is nil" code:0 userInfo:nil]);
        return nil;
    }
    
    // Re-create all all configuration agian.
    // Make the `resourceLoader` become the delegate of 'videoURLAsset', and provide data to the player.
    
    JXPlayerPlayVideoToolItem *item = [JXPlayerPlayVideoToolItem new];
    item.unownShowView = showView;
    JXPlayerResourceLoader *resourceLoader = [JXPlayerResourceLoader new];
    item.resourceLoader = resourceLoader;
    AVURLAsset *videoURLAsset = [AVURLAsset URLAssetWithURL:[self handleVideoURL] options:nil];
    [videoURLAsset.resourceLoader setDelegate:resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:videoURLAsset];
    {
        item.url = url;
        item.currentPlayerItem = playerItem;
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        
        item.player = [AVPlayer playerWithPlayerItem:playerItem];
        item.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:item.player];
        {
            NSString *videoGravity = nil;
            if (options&JXPlayerLayerVideoGravityResizeAspect) {
                videoGravity = AVLayerVideoGravityResizeAspect;
            }
            else if (options&JXPlayerLayerVideoGravityResize){
                videoGravity = AVLayerVideoGravityResize;
            }
            else if (options&JXPlayerLayerVideoGravityResizeAspectFill){
                videoGravity = AVLayerVideoGravityResizeAspectFill;
            }
            item.currentPlayerLayer.videoGravity = videoGravity;
        }
        {
            // add observer for video playing progress.
            __weak typeof(item) wItem = item;
            [item.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 10.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time){
                __strong typeof(wItem) sItem = wItem;
                if (!sItem) return;
                
                float current = CMTimeGetSeconds(time);
                float total = CMTimeGetSeconds(sItem.currentPlayerItem.duration);
                if (current && progress) {
                    progress(current / total);
                }
            }];
        }
        item.unownShowView.jx_backgroundLayer.frame = CGRectMake(0, 0, showView.bounds.size.width, showView.bounds.size.height);
        item.currentPlayerLayer.frame = item.unownShowView.jx_backgroundLayer.bounds;
        item.videoURLAsset = videoURLAsset;
        item.error = error;
        item.playerOptions = options;
        item.playingKey = [[JXPlayerManager sharedManager]cacheKeyForURL:url];
    }
    self.currentPlayVideoItem = item;
    
    if (options & JXPlayerMutedPlay) {
        item.player.muted = YES;
    }
    
    @synchronized (self) {
        [self.playVideoItems addObject:item];
    }
    self.currentPlayVideoItem = item;
    
    // play.
    [self.currentPlayVideoItem.resourceLoader didReceivedDataCacheInDiskByTempPath:tempVideoCachePath videoFileExceptSize:exceptSize videoFileReceivedSize:receivedSize];
    
    return item;
}

- (void)didReceivedDataCacheInDiskByTempPath:(NSString * _Nonnull)tempCacheVideoPath videoFileExceptSize:(NSUInteger)expectedSize videoFileReceivedSize:(NSUInteger)receivedSize{
    [self.currentPlayVideoItem.resourceLoader didReceivedDataCacheInDiskByTempPath:tempCacheVideoPath videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize];
}

- (void)didCachedVideoDataFinishedFromWebFullVideoCachePath:(NSString * _Nullable)fullVideoCachePath{
    if (self.currentPlayVideoItem.resourceLoader) {
        [self.currentPlayVideoItem.resourceLoader didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
    }
}

- (void)setMute:(BOOL)mute{
    self.currentPlayVideoItem.player.muted = mute;
}

- (void)stopPlay{
    self.currentPlayVideoItem = nil;
    for (JXPlayerPlayVideoToolItem *item in self.playVideoItems) {
        [item stopPlayVideo];
    }
    @synchronized (self) {
        if (self.playVideoItems)
        [self.playVideoItems removeAllObjects];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
        [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusStop];
    }
}

- (void)pause{
    [self.currentPlayVideoItem pausePlayVideo];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
        [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPause];
    }
}

- (void)resume{
    [self.currentPlayVideoItem resumePlayVideo];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
        [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPlaying];
    }
}


#pragma mark - App Observer

- (void)addObserverOnce{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appReceivedMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startDownload) name:JXPlayerDownloadStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedDownload) name:JXPlayerDownloadFinishNotification object:nil];
}

- (void)appReceivedMemoryWarning{
    [self.currentPlayVideoItem stopPlayVideo];
}

- (void)appDidEnterBackground{
    [self.currentPlayVideoItem pausePlayVideo];
    if (self.currentPlayVideoItem.unownShowView) {
        self.playingStatus_beforeEnterBackground = self.currentPlayVideoItem.unownShowView.playingStatus;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
        [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPause];
    }
}

- (void)appDidEnterPlayGround{
    // fixed #35.
    if (self.currentPlayVideoItem.unownShowView && (self.playingStatus_beforeEnterBackground == JXPlayerPlayingStatusPlaying)) {
        [self.currentPlayVideoItem resumePlayVideo];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
            [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPlaying];
        }
    }
    else{
        [self.currentPlayVideoItem pausePlayVideo];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
            [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPause];
        }
    }
}


#pragma mark - AVPlayer Observer

- (void)playerItemDidPlayToEnd:(NSNotification *)notification{
    
    // ask need automatic replay or not.
    if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:shouldAutoReplayVideoForURL:)]) {
        if (![self.delegate playVideoTool:self shouldAutoReplayVideoForURL:self.currentPlayVideoItem.url]) {
            return;
        }
    }
    
    // Seek the start point of file data and repeat play, this handle have no memory surge.
    __weak typeof(self.currentPlayVideoItem) weak_Item = self.currentPlayVideoItem;
    [self.currentPlayVideoItem.player seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finished) {
        __strong typeof(weak_Item) strong_Item = weak_Item;
        if (!strong_Item) return;
        
        self.currentPlayVideoItem.lastTime = 0;
        [strong_Item.player play];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
            [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPlaying];
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:{
                if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
                    [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusUnkown];
                }
            }
            break;
            
            case AVPlayerItemStatusReadyToPlay:{
                
                // When get ready to play note, we can go to play, and can add the video picture on show view.
                if (!self.currentPlayVideoItem) return;
                
                [self.currentPlayVideoItem.player play];
                [self hideActivaityIndicatorView];
                
                [self displayVideoPicturesOnShowLayer];
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
                    [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPlaying];
                }
            }
            break;
            
            case AVPlayerItemStatusFailed:{
                [self hideActivaityIndicatorView];
                
                if (self.currentPlayVideoItem.error) self.currentPlayVideoItem.error([NSError errorWithDomain:@"Some errors happen on player" code:0 userInfo:nil]);
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
                    [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusFailed];
                }
            }
            break;
            default:
            break;
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        // It means player buffering if the player time don't change,
        // else if the player time plus than before, it means begain play.
        // fixed #28.
        NSTimeInterval currentTime = CMTimeGetSeconds(self.currentPlayVideoItem.player.currentTime);
        
        if (currentTime != 0 && currentTime > self.currentPlayVideoItem.lastTime) {
            [self hideActivaityIndicatorView];
            self.currentPlayVideoItem.lastTime = currentTime;
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
                [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusPlaying];
            }
        }
        else{
            [self showActivaityIndicatorView];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(playVideoTool:playingStatuDidChanged:)]) {
                [self.delegate playVideoTool:self playingStatuDidChanged:JXPlayerPlayingToolStatusBuffering];
            }
        }
    }
}


#pragma mark - Private

- (void)startDownload{
    [self showActivaityIndicatorView];
}

- (void)finishedDownload{
    [self hideActivaityIndicatorView];
}

- (void)showActivaityIndicatorView{
    if (self.currentPlayVideoItem.playerOptions&JXPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.currentPlayVideoItem.unownShowView performSelector:NSSelectorFromString(@"jx_showActivityIndicatorView")];
#pragma clang diagnostic pop
    }
}

- (void)hideActivaityIndicatorView{
    if (self.currentPlayVideoItem.playerOptions&JXPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.currentPlayVideoItem.unownShowView performSelector:NSSelectorFromString(@"jx_hideActivityIndicatorView")];
#pragma clang diagnostic pop
    }
}

- (void)setCurrentPlayVideoItem:(JXPlayerPlayVideoToolItem *)currentPlayVideoItem{
    [self willChangeValueForKey:@"currentPlayVideoItem"];
    _currentPlayVideoItem = currentPlayVideoItem;
    [self didChangeValueForKey:@"currentPlayVideoItem"];
}

- (NSURL *)handleVideoURL{
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:JXPlayerURL] resolvingAgainstBaseURL:NO];
    components.scheme = JXPlayerURLScheme;
    return [components URL];
}

- (void)displayVideoPicturesOnShowLayer{
    if (!self.currentPlayVideoItem.isCancelled) {
        // fixed #26.
        [self.currentPlayVideoItem.unownShowView.jx_backgroundLayer addSublayer:self.currentPlayVideoItem.currentPlayerLayer];
    }
}

@end
