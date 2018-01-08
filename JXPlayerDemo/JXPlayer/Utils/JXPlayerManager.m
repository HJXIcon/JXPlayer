//
//  JXPlayerManger.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerManager.h"
#import "JXPlayerOperation.h"
#import "JXPlayerPlayVideoTool.h"
#import "JXPlayerCompat.h"
#import "UIView+WebVideoCacheOperation.h"
#import "UIView+WebVideoCache.h"


#pragma mark - *** JXPlayerCombinedOperation
@interface JXPlayerCombinedOperation : NSObject <JXPlayerOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;

@property (copy, nonatomic, nullable) JXPlayerNoParamsBlock cancelBlock;

@property (strong, nonatomic, nullable) NSOperation *cacheOperation;

@end

@implementation JXPlayerCombinedOperation

- (void)setCancelBlock:(nullable JXPlayerNoParamsBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        _cancelBlock = nil;
    }
}

@end

#pragma mark - *** JXPlayerManager
@interface JXPlayerManager()<JXPlayerPlayVideoToolDelegate>

@property (strong, nonatomic, readwrite, nonnull) JXPlayerCache *videoCache;

@property (strong, nonatomic, readwrite, nonnull) JXPlayerDownloader *videoDownloader;

@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;

@property (strong, nonatomic, nonnull) NSMutableArray<JXPlayerCombinedOperation *> *runningOperations;

@property(nonatomic, getter=isMuted) BOOL mute;

@property (strong, nonatomic, nonnull) NSMutableArray<UIView *> *showViews;

@end

@implementation JXPlayerManager

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    JXPlayerCache *cache = [JXPlayerCache sharedCache];
    JXPlayerDownloader *downloader = [JXPlayerDownloader sharedDownloader];
    return [self initWithCache:cache downloader:downloader];
}

- (nonnull instancetype)initWithCache:(nonnull JXPlayerCache *)cache downloader:(nonnull JXPlayerDownloader *)downloader {
    if ((self = [super init])) {
        _videoCache = cache;
        _videoDownloader = downloader;
        _failedURLs = [NSMutableSet new];
        _runningOperations = [NSMutableArray array];
        _showViews = [NSMutableArray array];
    }
    return self;
}


#pragma mark - Public

- (nullable id <JXPlayerOperation>)loadVideoWithURL:(nullable NSURL *)url showOnView:(nullable UIView *)showView options:(JXPlayerOptions)options progress:(nullable JXPlayerDownloaderProgressBlock)progressBlock completed:(nullable JXPlayerCompletionBlock)completedBlock{
    
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    __block JXPlayerCombinedOperation *operation = [JXPlayerCombinedOperation new];
    __weak JXPlayerCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    if (url) {
        @synchronized (self.failedURLs) {
            isFailedUrl = [self.failedURLs containsObject:url];
        }
    }
    
    if (url.absoluteString.length == 0 || (!(options & JXPlayerRetryFailed) && isFailedUrl)) {
        [self callCompletionBlockForOperation:operation completion:completedBlock videoPath:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] cacheType:JXPlayerCacheTypeNone url:url];
        return operation;
    }
    
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    
    @synchronized (self.showViews) {
        [self.showViews addObject:showView];
    }
    
    NSString *key = [self cacheKeyForURL:url];
    
    BOOL isFileURL = [url isFileURL];
    
    // show progress view and activity indicator view if need.
    [self showProgressViewAndActivityIndicatorViewForView:showView options:options];
    
    __weak typeof(showView) wShowView = showView;
    if (isFileURL) {
#pragma mark - Local File
        // hide activity view.
        [self hideActivityViewWithURL:url options:options];
        
        // local file.
        NSString *path = [url.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            
            BOOL needDisplayProgress = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:1.0];
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            if (needDisplayProgress) {
                [showView performSelector:NSSelectorFromString(@"jx_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
            }
            
            // display backLayer.
            [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
            
            [[JXPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:path options:options showOnView:showView playingProgress:^(CGFloat progress) {
                __strong typeof(wShowView) sShowView = wShowView;
                if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                BOOL needDisplayProgress = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
                if (needDisplayProgress) {
                    [sShowView performSelector:NSSelectorFromString(@"jx_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                }
#pragma clang diagnostic pop
            } error:^(NSError * _Nullable error) {
                if (completedBlock) {
                    completedBlock(nil, error, JXPlayerCacheTypeLocation, url);
                }
            }];
            [JXPlayerPlayVideoTool sharedTool].delegate = self;
        }
        else{
            [self callCompletionBlockForOperation:operation completion:completedBlock videoPath:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] cacheType:JXPlayerCacheTypeNone url:url];
            // hide progress view.
            [self hideProgressViewWithURL:url options:options];
            return operation;
        }
    }
    else{
        operation.cacheOperation = [self.videoCache queryCacheOperationForKey:key done:^(NSString * _Nullable videoPath, JXPlayerCacheType cacheType) {
            
            if (operation.isCancelled) {
                [self safelyRemoveOperationFromRunning:operation];
                return;
            }
            
            // NO cache in disk or the delegate do not responding the `videoPlayerManager:shouldDownloadVideoForURL:`,  or the delegate allow download video.
            if (!videoPath && (![self.delegate respondsToSelector:@selector(videoPlayerManager:shouldDownloadVideoForURL:)] || [self.delegate videoPlayerManager:self shouldDownloadVideoForURL:url])) {
                
                // cache token.
                __block  JXPlayerCacheToken *cacheToken = nil;
                
                // download if no cache, and download allowed by delegate.
                JXPlayerDownloaderOptions downloaderOptions = 0;
                {
                    if (options & JXPlayerContinueInBackground)
                    downloaderOptions |= JXPlayerDownloaderContinueInBackground;
                    if (options & JXPlayerHandleCookies)
                    downloaderOptions |= JXPlayerDownloaderHandleCookies;
                    if (options & JXPlayerAllowInvalidSSLCertificates)
                    downloaderOptions |= JXPlayerDownloaderAllowInvalidSSLCertificates;
                    if (options & JXPlayerShowProgressView)
                    downloaderOptions |= JXPlayerDownloaderShowProgressView;
                    if (options & JXPlayerShowActivityIndicatorView)
                    downloaderOptions |= JXPlayerDownloaderShowActivityIndicatorView;
                }
                
                // Save received data to disk.
                JXPlayerDownloaderProgressBlock handleProgressBlock = ^(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempVideoCachedPath, NSURL * _Nullable targetURL){
                    
                    cacheToken = [self.videoCache storeVideoData:data expectedSize:expectedSize forKey:key completion:^(NSUInteger storedSize, NSError * _Nullable error, NSString * _Nullable fullVideoCachePath) {
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        
                        if (!strongOperation || strongOperation.isCancelled) {
                            // Do nothing if the operation was cancelled
                            // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                        }
                        if (!error) {
                            
                            // refresh progress view.
                            [self progressRefreshWithURL:targetURL options:options receiveSize:storedSize exceptSize:expectedSize];
                            
                            if (!fullVideoCachePath) {
                                if (progressBlock) {
                                    progressBlock(data, storedSize, expectedSize, tempVideoCachedPath, targetURL);
                                }
#pragma mark - Play video from web
                                { // play video from web.
                                    if (![JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
                                        __strong typeof(wShowView) sShowView = wShowView;
                                        if (!sShowView) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                        // display backLayer.
                                        [sShowView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                                        [[JXPlayerPlayVideoTool sharedTool] playVideoWithURL:url tempVideoCachePath:tempVideoCachedPath options:options videoFileExceptSize:expectedSize videoFileReceivedSize:storedSize showOnView:sShowView playingProgress:^(CGFloat progress) {
                                            BOOL needDisplayProgress = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                            if (needDisplayProgress) {
                                                [sShowView performSelector:NSSelectorFromString(@"jx_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                                            }
#pragma clang diagnostic pop
                                            
                                        } error:^(NSError * _Nullable error) {
                                            if (error) {
                                                if (completedBlock) {
                                                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:videoPath error:error cacheType:JXPlayerCacheTypeNone url:targetURL];
                                                    // hide indicator.
                                                    // [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                                                    [self safelyRemoveOperationFromRunning:operation];
                                                }
                                            }
                                        }];
                                        [JXPlayerPlayVideoTool sharedTool].delegate = self;
                                    }
                                    else{
                                        NSString *key = [[JXPlayerManager sharedManager] cacheKeyForURL:targetURL];
                                        if ([JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem && [key isEqualToString:[JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem.playingKey]) {
                                            [[JXPlayerPlayVideoTool sharedTool] didReceivedDataCacheInDiskByTempPath:tempVideoCachedPath videoFileExceptSize:expectedSize videoFileReceivedSize:receivedSize];
                                        }
                                    }
                                }
                            }
                            else{
#pragma mark - Cache Finished.
                                // cache finished, and move the full video file from temporary path to full path.
                                [[JXPlayerPlayVideoTool sharedTool] didCachedVideoDataFinishedFromWebFullVideoCachePath:fullVideoCachePath];
                                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:fullVideoCachePath error:nil cacheType:JXPlayerCacheTypeNone url:url];
                                [self safelyRemoveOperationFromRunning:strongOperation];
                                
                                if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)]) {
                                    [self.delegate videoPlayerManager:self downloadingProgressDidChanged:1];
                                }
                            }
                        }
                        else{
                            // some error happens.
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:error cacheType:JXPlayerCacheTypeNone url:url];
                            
                            // hide indicator view.
                            [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                            [self safelyRemoveOperationFromRunning:strongOperation];
                        }
                    }];
                };
                
                // delete all temporary first, then download video from web.
                [self.videoCache deleteAllTempCacheOnCompletion:^{
                    
                    JXPlayerDownloadToken *subOperationToken = [self.videoDownloader downloadVideoWithURL:url options:downloaderOptions progress:handleProgressBlock completed:^(NSError * _Nullable error) {
                        
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        if (!strongOperation || strongOperation.isCancelled) {
                            // Do nothing if the operation was cancelled.
                            // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data.
                        }
                        else if (error){
                            [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:error cacheType:JXPlayerCacheTypeNone url:url];
                            
                            if (   error.code != NSURLErrorNotConnectedToInternet
                                && error.code != NSURLErrorCancelled
                                && error.code != NSURLErrorTimedOut
                                && error.code != NSURLErrorInternationalRoamingOff
                                && error.code != NSURLErrorDataNotAllowed
                                && error.code != NSURLErrorCannotFindHost
                                && error.code != NSURLErrorCannotConnectToHost) {
                                @synchronized (self.failedURLs) {
                                    [self.failedURLs addObject:url];
                                }
                            }
                            
                            [self safelyRemoveOperationFromRunning:strongOperation];
                        }
                        else{
                            if ((options & JXPlayerRetryFailed)) {
                                @synchronized (self.failedURLs) {
                                    if ([self.failedURLs containsObject:url]) {
                                        [self.failedURLs removeObject:url];
                                    }
                                }
                            }
                        }
                    }];
                    
                    operation.cancelBlock = ^{
                        [self.videoCache cancel:cacheToken];
                        [self.videoDownloader cancel:subOperationToken];
                        [[JXPlayerManager sharedManager] stopPlay];
                        
                        // hide indicator view.
                        [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                        
                        __strong __typeof(weakOperation) strongOperation = weakOperation;
                        [self safelyRemoveOperationFromRunning:strongOperation];
                    };
                }];
            }
            else if(videoPath){
#pragma mark - Full video cache file in disk
                // full video cache file in disk.
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                
                // hide activity view.
                [self hideActivityViewWithURL:url options:options];
                
                // play video from disk.
                if (cacheType==JXPlayerCacheTypeDisk) {
                    BOOL needDisplayProgressView = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:1.0];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    if (needDisplayProgressView) {
                        [showView performSelector:NSSelectorFromString(@"jx_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@1];
                    }
                    // display backLayer.
                    [showView performSelector:NSSelectorFromString(@"displayBackLayer")];
#pragma clang diagnostic pop
                    
                    [[JXPlayerPlayVideoTool sharedTool] playExistedVideoWithURL:url fullVideoCachePath:videoPath options:options showOnView:showView playingProgress:^(CGFloat progress) {
                        __strong typeof(wShowView) sShowView = wShowView;
                        if (!sShowView) return;
                        
                        BOOL needDisplayProgressView = [self needDisplayPlayingProgressViewWithPlayingProgressValue:progress];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        if (needDisplayProgressView) {
                            [sShowView performSelector:NSSelectorFromString(@"jx_progressViewPlayingStatusChangedWithProgressValue:") withObject:@(progress)];
                        }
#pragma clang diagnostic pop
                    } error:^(NSError * _Nullable error) {
                        if (completedBlock) {
                            completedBlock(nil, error, JXPlayerCacheTypeLocation, url);
                        }
                    }];
                    [JXPlayerPlayVideoTool sharedTool].delegate = self;
                }
                
                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:videoPath error:nil cacheType:JXPlayerCacheTypeDisk url:url];
                [self safelyRemoveOperationFromRunning:operation];
            }
            else {
                // video not in cache and download disallowed by delegate.
                
                // hide activity and progress view.
                [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
                
                __strong __typeof(weakOperation) strongOperation = weakOperation;
                [self callCompletionBlockForOperation:strongOperation completion:completedBlock videoPath:nil error:nil cacheType:JXPlayerCacheTypeNone url:url];
                [self safelyRemoveOperationFromRunning:operation];
                // hide indicator view.
                [self hideAllIndicatorAndProgressViewsWithURL:url options:options];
            }
        }];
    }
    
    return operation;
}

- (void)cancelAllDownloads{
    [self.videoDownloader cancelAllDownloads];
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    //#pragma clang diagnostic push
    //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //    url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
    //#pragma clang diagnostic pop
    return [url absoluteString];
}

- (void)stopPlay{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    dispatch_main_async_safe(^{
        if (self.showViews.count) {
            for (UIView *view in self.showViews) {
                [view performSelector:NSSelectorFromString(@"jx_removeVideoLayerViewAndIndicatorView")];
                [view performSelector:NSSelectorFromString(@"jx_hideActivityIndicatorView")];
                [view performSelector:NSSelectorFromString(@"jx_hideProgressView")];
                view.currentPlayingURL = nil;
            }
            [self.showViews removeAllObjects];
        }
        
        [[JXPlayerPlayVideoTool sharedTool] stopPlay];
    });
#pragma clang diagnostic pop
}

- (void)pause{
    [[JXPlayerPlayVideoTool sharedTool] pause];
}

- (void)resume{
    [[JXPlayerPlayVideoTool sharedTool] resume];
}

- (void)setPlayerMute:(BOOL)mute{
    if ([JXPlayerPlayVideoTool sharedTool].currentPlayVideoItem) {
        [[JXPlayerPlayVideoTool sharedTool] setMute:mute];
    }
    self.mute = mute;
}

- (BOOL)playerIsMute{
    return self.mute;
}


#pragma mark - JXPlayerPlayVideoToolDelegate

- (BOOL)playVideoTool:(JXPlayerPlayVideoTool *)videoTool shouldAutoReplayVideoForURL:(NSURL *)videoURL{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:shouldAutoReplayForURL:)]) {
        return [self.delegate videoPlayerManager:self shouldAutoReplayForURL:videoURL];
    }
    return YES;
}

- (void)playVideoTool:(JXPlayerPlayVideoTool *)videoTool playingStatuDidChanged:(JXPlayerPlayingStatus)playingStatus{
    if (self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingStatusDidChanged:)]) {
        [self.delegate videoPlayerManager:self playingStatusDidChanged:playingStatus];
    }
}


#pragma mark - Private

- (BOOL)needDisplayDownloadingProgressViewWithDownloadingProgressValue:(CGFloat)downloadingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:downloadingProgressDidChanged:)];
    BOOL download = [self.delegate videoPlayerManager:self downloadingProgressDidChanged:downloadingProgress];
    return  respond && download;
}

- (BOOL)needDisplayPlayingProgressViewWithPlayingProgressValue:(CGFloat)playingProgress{
    BOOL respond = self.delegate && [self.delegate respondsToSelector:@selector(videoPlayerManager:playingProgressDidChanged:)];
    BOOL playing = [self.delegate videoPlayerManager:self playingProgressDidChanged:playingProgress];
    return  respond && playing;
}

- (void)hideAllIndicatorAndProgressViewsWithURL:(nullable NSURL *)url options:(JXPlayerOptions)options{
    [self hideActivityViewWithURL:url options:options];
    [self hideProgressViewWithURL:url options:options];
}

- (void)hideActivityViewWithURL:(nullable NSURL *)url options:(JXPlayerOptions)options{
    if (options & JXPlayerShowActivityIndicatorView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jx_hideActivityIndicatorView")];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)hideProgressViewWithURL:(nullable NSURL *)url options:(JXPlayerOptions)options{
    if (![self needDisplayPlayingProgressViewWithPlayingProgressValue:0] || ![self needDisplayDownloadingProgressViewWithDownloadingProgressValue:0]) {
        return;
    }
    
    if (options & JXPlayerShowProgressView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jx_hideProgressView")];
            }
        });
    }
#pragma clang diagnostic pop
}

- (void)progressRefreshWithURL:(nullable NSURL *)url options:(JXPlayerOptions)options receiveSize:(NSUInteger)receiveSize exceptSize:(NSUInteger)expectedSize{
    if (![self needDisplayDownloadingProgressViewWithDownloadingProgressValue:(CGFloat)receiveSize/expectedSize]) {
        return;
    }
    
    if (options & JXPlayerShowProgressView){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dispatch_main_async_safe(^{
            UIView *view = nil;
            for (UIView *v in self.showViews) {
                if (v.currentPlayingURL && [v.currentPlayingURL.absoluteString isEqualToString:url.absoluteString]) {
                    view = v;
                    break;
                }
            }
            if (view) {
                [view performSelector:NSSelectorFromString(@"jx_progressViewDownloadingStatusChangedWithProgressValue:") withObject:@((CGFloat)receiveSize/expectedSize)];
            }
        });
#pragma clang diagnostic pop
    }
}

- (void)showProgressViewAndActivityIndicatorViewForView:(UIView *)view options:(JXPlayerOptions)options{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    dispatch_main_async_safe(^{
        BOOL needDisplayProgress = [self needDisplayDownloadingProgressViewWithDownloadingProgressValue:0] || [self needDisplayPlayingProgressViewWithPlayingProgressValue:0];
        
        if ((options & JXPlayerShowProgressView) && needDisplayProgress) {
            [view performSelector:NSSelectorFromString(@"jx_showProgressView")];
        }
        if ((options & JXPlayerShowActivityIndicatorView)) {
            [view performSelector:NSSelectorFromString(@"jx_showActivityIndicatorView")];
        }
    });
#pragma clang diagnostic pop
}

- (void)safelyRemoveOperationFromRunning:(nullable JXPlayerCombinedOperation*)operation {
    @synchronized (self.runningOperations) {
        if (operation) {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable JXPlayerCombinedOperation*)operation completion:(nullable JXPlayerCompletionBlock)completionBlock videoPath:(nullable NSString *)videoPath error:(nullable NSError *)error cacheType:(JXPlayerCacheType)cacheType url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (operation && !operation.isCancelled && completionBlock) {
            completionBlock(videoPath, error, cacheType, url);
        }
    });
}

- (void)diskVideoExistsForURL:(nullable NSURL *)url completion:(nullable JXPlayerCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    [self.videoCache diskVideoExistsWithKey:key completion:^(BOOL isInDiskCache) {
        if (completionBlock) {
            completionBlock(isInDiskCache);
        }
    }];
}


@end
