//
//  JXPlayerDownloader.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerDownloader.h"
#import "JXPlayerCompat.h"
#import "JXPlayerDownloaderOperation.h"

@implementation JXPlayerDownloadToken

@end

#pragma mark - *** JXPlayerDownloader
@interface JXPlayerDownloader ()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;

@property (assign, nonatomic, nullable) Class operationClass;

@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, JXPlayerDownloaderOperation *> *URLOperations;

@property (strong, nonatomic, nullable) JXHTTPHeadersMutableDictionary *HTTPHeaders;

@property (nonatomic, nullable) dispatch_queue_t barrierQueue;

@property (strong, nonatomic) NSURLSession *session;

@end

@implementation JXPlayerDownloader

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
        _operationClass = [JXPlayerDownloaderOperation class];
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 3;
        _downloadQueue.name = @"com.HJXIcon.JXPlayerDownloader";
        _URLOperations = [NSMutableDictionary new];
        _HTTPHeaders = [@{@"Accept": @"video/mpeg"} mutableCopy];
        _barrierQueue = dispatch_queue_create("com.HJXIcon.JXPlayerDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;
        
        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        // self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.downloadQueue cancelAllOperations];
}


#pragma mark - Public

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    }
    else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    return self.HTTPHeaders[field];
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nullable JXPlayerDownloadToken *)downloadVideoWithURL:(NSURL *)url options:(JXPlayerDownloaderOptions)options progress:(JXPlayerDownloaderProgressBlock)progressBlock completed:(JXPlayerDownloaderErrorBlock)errorBlock{
    
    __weak typeof(self) weakSelf = self;
    
    return [self addProgressCallback:progressBlock completedBlock:errorBlock forURL:url createCallback:^JXPlayerDownloaderOperation *{
        
        __strong __typeof (weakSelf) sself = weakSelf ;
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        // In order to prevent from potential duplicate caching (NSURLCache + JXPlayerCache) we disable the cache for image requests if told otherwise.
        NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        actualURLComponents.scheme = url.scheme;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[actualURLComponents URL] cachePolicy:(NSURLRequestReloadIgnoringLocalCacheData) timeoutInterval:timeoutInterval];
        
        request.HTTPShouldHandleCookies = (options & JXPlayerDownloaderHandleCookies);
        request.HTTPShouldUsePipelining = YES;
        if (sself.headersFilter) {
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself.HTTPHeaders copy]);
        }
        
        JXPlayerDownloaderOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session options:options];
        
        if (sself.urlCredential) {
            operation.credential = sself.urlCredential;
        }
        else if (sself.username && sself.password) {
            operation.credential = [NSURLCredential credentialWithUser:sself.username password:sself.password persistence:NSURLCredentialPersistenceForSession];
        }
        
        [sself.downloadQueue addOperation:operation];
        
        return operation;
    }];
}

- (void)cancel:(JXPlayerDownloadToken *)token{
    dispatch_barrier_async(self.barrierQueue, ^{
        JXPlayerDownloaderOperation *operation = self.URLOperations[token.url];
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:token.url];
        }
    });
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}


#pragma mark - Private

- (nullable JXPlayerDownloadToken *)addProgressCallback:(JXPlayerDownloaderProgressBlock)progressBlock completedBlock:(JXPlayerDownloaderErrorBlock)errorBlock forURL:(nullable NSURL *)url createCallback:(JXPlayerDownloaderOperation *(^)(void))createCallback {
    
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no video or data.
    if (url == nil) {
        if (errorBlock) {
            errorBlock([NSError errorWithDomain:@"Please check the URL, because it is nil" code:0 userInfo:nil]);
        }
        return nil;
    }
    
    __block JXPlayerDownloadToken *token = nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        JXPlayerDownloaderOperation *operation = self.URLOperations[url];
        if (!operation) {
            operation = createCallback();
            self.URLOperations[url] = operation;
            
            __weak JXPlayerDownloaderOperation *woperation = operation;
            operation.completionBlock = ^{
                JXPlayerDownloaderOperation *soperation = woperation;
                if (!soperation) return;
                if (self.URLOperations.allKeys.count>0) {
                    if (self.URLOperations[url] == soperation) {
                        [self.URLOperations removeObjectForKey:url];
                    };
                }
            };
        }
        id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock error:errorBlock];
        
        token = [JXPlayerDownloadToken new];
        token.url = url;
        token.downloadOperationCancelToken = downloadOperationCancelToken;
    });
    
    return token;
}


@end
