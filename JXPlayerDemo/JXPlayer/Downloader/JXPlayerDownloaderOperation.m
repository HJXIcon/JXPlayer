//
//  JXPlayerDownloaderOperation.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerDownloaderOperation.h"
#import "JXPlayerCache.h"
#import "JXPlayerManager.h"
#import "JXPlayerCompat.h"
#import "JXPlayerCachePathTool.h"

NSString *const JXPlayerDownloadStartNotification = @"www.jxplayer.download.start.notification";
NSString *const JXPlayerDownloadReceiveResponseNotification = @"www.jxplayer.download.received.response.notification";
NSString *const JXPlayerDownloadStopNotification = @"www.jxplayer.download.stop.notification";
NSString *const JXPlayerDownloadFinishNotification = @"www.jxplayer.download.finished.notification";

static NSString *const kProgressCallbackKey = @"www.jxplayer.progress.callback";
static NSString *const kErrorCallbackKey = @"www.jxplayer.error.callback";

typedef NSMutableDictionary<NSString *, id> JXCallbacksDictionary;


@interface JXPlayerDownloaderOperation()

@property (strong, nonatomic, nonnull)NSMutableArray<JXCallbacksDictionary *> *callbackBlocks;
// 任务的执行状态
@property (assign, nonatomic, getter = isExecuting)BOOL executing;
// 任务是否执行完毕
@property (assign, nonatomic, getter = isFinished)BOOL finished;

@property (weak, nonatomic, nullable) NSURLSession *unownedSession;

@property (strong, nonatomic, nullable) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;

@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;

// 通过UIBackgroundTaskIdentifier可以实现有限时间内在后台运行程序
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property(nonatomic, assign)NSUInteger receiveredSize;

@end

@implementation JXPlayerDownloaderOperation{
    BOOL responseFromCached;
}


@synthesize executing = _executing;
@synthesize finished = _finished;

#pragma mark - init
- (nonnull instancetype)init{
    return [self initWithRequest:nil inSession:nil options:0];
}

#pragma mark - Public Method
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(JXPlayerDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _options = options;
        _callbackBlocks = [NSMutableArray new];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        responseFromCached = YES; // Initially wrong until `- URLSession:dataTask:willCacheResponse:completionHandler: is called or not called
        // 生成一个并发执行队列，block被分发到多个线程去执行
        _barrierQueue = dispatch_queue_create("com.HJXIcon.JXPlayerDownloaderOperationBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (nullable id)addHandlersForProgress:(nullable JXPlayerDownloaderProgressBlock)progressBlock error:(nullable JXPlayerDownloaderErrorBlock)errorBlock{
    
    JXCallbacksDictionary *callbacks = [NSMutableDictionary new];
    
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (errorBlock) callbacks[kErrorCallbackKey] = [errorBlock copy];
    
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    
    return callbacks;
}

- (BOOL)cancel:(nullable id)token {
    __block BOOL shouldCancel = NO;
    dispatch_barrier_sync(self.barrierQueue, ^{
        // 删除数组中指定元素,根据对象的地址判断
        [self.callbackBlocks removeObjectIdenticalTo:token];
        if (self.callbackBlocks.count == 0) {
            shouldCancel = YES;
        }
    });
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}

#pragma mark - Override Required
// 核心方法：在该方法中处理视频下载操作
- (void)start {
    // 1.创建一个互斥锁，保证在同一时间内没有其它线程对self对象进行修改，起到线程的保护作用， 一般在公用变量的时候使用，如单例模式或者操作类的static变量中使用。
    @synchronized (self) {
        
        // 2.判断当前操作是否被取消，如果被取消了，则标记任务结束，并处理后续的block和清理操作
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        
        // 3.如果没被取消，开始执行任务
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        
        // 程序即将进入后台
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak __typeof__ (self) wself = self;
            // 获得UIApplication单例对象
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            
            /**!
             正常程序退出后，会在几秒内停止工作；要想申请更长的时间，需要用到beginBackgroundTaskWithExpirationHandler
                 endBackgroundTask
             一定要成对出现
             */
            //UIBackgroundTaskIdentifier：通过UIBackgroundTaskIdentifier可以实现有限时间内在后台运行程序
            //在后台获取一定的时间去指行我们的代码
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;
                
                if (sself) {
                    [sself cancel];//取消当前下载操作
                    [app endBackgroundTask:sself.backgroundTaskId];//结束后台任务
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
        else{
            return;
        }
        
        //创建NSURLSession对象，并设置代理（没有马上发送请求）
        NSURLSession *session = self.unownedSession;
        if (!self.unownedSession) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
            session = self.ownedSession;
        }
        // 开启任务
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;//当前任务正在执行
    }
    // 恢复
    [self.dataTask resume];
    
    if (self.dataTask) {
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStartNotification object:self];
        });
        
        @autoreleasepool {
            // 在这里定义自己的并发任务
            for (JXPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
                progressBlock(nil, 0, NSURLResponseUnknownLength, nil, self.request.URL);
            }
        }
    }
    else {
        [self callErrorBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}]];
    }
    
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

#pragma mark - NSURLSessionDataDelegate
// 1.接收到服务器的响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    //'304 Not Modified' is an exceptional one.
    if (![response respondsToSelector:@selector(statusCode)] || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        
        NSInteger expected = MAX((NSInteger)response.expectedContentLength, 0);
        self.expectedSize = expected;
        
        @autoreleasepool {
            for (JXPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
                
                // May the free size of the device less than the expected size of the video data.
                if (![[JXPlayerCache sharedCache] haveFreeSizeToCacheFileWithSize:expected]) {
                    if (completionHandler) {
                        completionHandler(NSURLSessionResponseCancel);
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStopNotification object:self];
                    });
                    
                    [self callErrorBlocksWithError:[NSError errorWithDomain:@"No enough size of device to cache the video data" code:0 userInfo:nil]];
                    
                    [self done];
                    
                    return;
                }
                else{
                    NSString *key = [[JXPlayerManager sharedManager] cacheKeyForURL:self.request.URL];
                    progressBlock(nil, 0, expected, [JXPlayerCachePathTool videoCacheTemporaryPathForKey:key], response.URL);
                }
            }
        }
        
        if (completionHandler) {
            // 允许处理服务器的响应，才会继续接收服务器返回的数据
            completionHandler(NSURLSessionResponseAllow);
        }
        self.response = response;
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadReceiveResponseNotification object:self];
        });
    }
    else {
        NSUInteger code = ((NSHTTPURLResponse *)response).statusCode;
        
        // This is the case when server returns '304 Not Modified'. It means that remote video is not changed.
        // In case of 304 we need just cancel the operation and return cached video from the cache.
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
        }
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStopNotification object:self];
        });
        
        [self callErrorBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:((NSHTTPURLResponse *)response).statusCode userInfo:nil]];
        
        // 完成
        [self done];
    }
}
// 2.接收到服务器的数据（可能调用多次）
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *key = [[JXPlayerManager sharedManager] cacheKeyForURL:self.request.URL];
    self.receiveredSize += data.length;
    
    @autoreleasepool {
        for (JXPlayerDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(data, self.receiveredSize, self.expectedSize, [JXPlayerCachePathTool videoCacheTemporaryPathForKey:key], self.request.URL);
        }
    }
}

// 3.请求成功或者失败（如果失败，error有值）
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    @synchronized(self) {
        self.dataTask = nil;
        
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStopNotification object:self];
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadFinishNotification object:self];
            }
        });
    }
    
    if (!error) {
        if (self.completionBlock) {
            self.completionBlock();
        }
    }
    else{
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStopNotification object:self];
        });
        [self callErrorBlocksWithError:error];
    }
    
    [self done];
}

/*
 只要请求的地址是HTTPS的, 就会调用这个代理方法
 我们需要在该方法中告诉系统, 是否信任服务器返回的证书
 Challenge: 挑战 质问 (包含了受保护的区域)
 protectionSpace : 受保护区域
 NSURLAuthenticationMethodServerTrust : 证书的类型是 服务器信任
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & JXPlayerDownloaderAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

// 决定是否使用缓存
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    // If this method is called, it means the response wasn't read from cache
    responseFromCached = NO;
    NSCachedURLResponse *cachedResponse = proposedResponse;
    
    if (self.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}


#pragma mark - Private

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    
    if (self.dataTask) {
        [self.dataTask cancel];
        dispatch_main_async_safe(^{
            [[NSNotificationCenter defaultCenter] postNotificationName:JXPlayerDownloadStopNotification object:self];
        });
        
        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    [self reset];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)callErrorBlocksWithError:(nullable NSError *)error {
    NSArray<id> *errorBlocks = [self callbacksForKey:kErrorCallbackKey];
    dispatch_main_async_safe(^{
        for (JXPlayerDownloaderErrorBlock errorBlock in errorBlocks) {
            errorBlock(error);
        }
    });
}

- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    
    __block NSMutableArray<id> *callbacks = nil;
    
    dispatch_sync(self.barrierQueue, ^{
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });
    return [callbacks copy];    // strip mutability here
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & JXPlayerDownloaderContinueInBackground;
}


- (void)reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}


#pragma mark - *** setter/getter
- (void)setFinished:(BOOL)finished {
    // 要实现相应的KVO
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    // 要实现相应的KVO
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

@end




