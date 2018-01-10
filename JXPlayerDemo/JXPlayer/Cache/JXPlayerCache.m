//
//  JXPlayerCache.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerCache.h"
#import "JXPlayerDownloaderOperation.h"
#import <UIKit/UIKit.h>
#import "JXPlayerManager.h"
#import "JXPlayerCachePathTool.h"
#import "NSURL+StripQuery.h"
#import "JXPlayerCompat.h"

#include <sys/param.h>
#include <sys/mount.h>
#import <CommonCrypto/CommonDigest.h>

#pragma mark - *** JXPlayerCacheToken
@interface JXPlayerCacheToken()

/**
输出流
 */
@property(nonnull, nonatomic, strong)NSOutputStream *outputStream;

/**
 已经写入的二进制文件大小
 */
@property(nonatomic, assign)NSUInteger receivedVideoSize;

/**
 指定的键
 */
@property(nonnull, nonatomic, strong)NSString *key;

@end

@implementation JXPlayerCacheToken

@end

#pragma mark - ***JXPlayerCache

@interface JXPlayerCache()

/**
 串行队列、先进先出
 */
@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

/**
 输出流信息数组
 */
@property(nonatomic, strong, nonnull)NSMutableArray<JXPlayerCacheToken *> *outputStreams;

/**
 标记视频二进制文件是否完全写入、是否回到主线程执行回调block
 */
@property(nonatomic, assign, getter=isCompletionBlockEnable)BOOL completionBlockEnable;

@end


@implementation JXPlayerCache{
    NSFileManager *_fileManager;
}

#pragma mark - *** init
- (instancetype)init{
    self = [super init];
    if (self) {
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.HJXIcon.JXPlayerCache", DISPATCH_QUEUE_SERIAL);
        
        _config = [[JXPlayerCacheConfig alloc] init];
        _fileManager = [NSFileManager defaultManager];
        _outputStreams = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadVideoDidStart:) name:JXPlayerDownloadStartNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteOldFiles)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

+ (nonnull instancetype)sharedCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}


- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Notification Action

- (void)downloadVideoDidStart:(NSNotification *)notification{
    JXPlayerDownloaderOperation *operation = notification.object;
    NSURL *url = operation.request.URL;
    NSString *key = [[JXPlayerManager sharedManager] cacheKeyForURL:url];
    [self removeTempCacheForKey:key withCompletion:nil];
    
    @autoreleasepool {
        [self.outputStreams removeAllObjects];
    }
}

- (void)deleteOldFiles {
    [self deleteOldFilesWithCompletionBlock:nil];
    [self deleteAllTempCacheOnCompletion:nil];
}

- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}


#pragma mark - *** Public Method
- (nullable JXPlayerCacheToken *)storeVideoData:(nullable NSData *)videoData expectedSize:(NSUInteger)expectedSize forKey:(nullable NSString *)key completion:(nullable JXPlayerStoreDataFinishedBlock)completionBlock{
    
    //如果视频或对应的key为空，那么就直接返回
    if (videoData.length==0) return nil;
    
    if (key.length==0) {
        if (completionBlock)
        completionBlock(0, [NSError errorWithDomain:@"Need a key for storing video data" code:0 userInfo:nil], nil);
        return nil;
    }
    
    // 检查是否有足够的存储空间
    if (![self haveFreeSizeToCacheFileWithSize:expectedSize]) {
        if (completionBlock)
        completionBlock(0, [NSError errorWithDomain:@"No enough size of device to cache the video data" code:0 userInfo:nil], nil);
        return nil;
    }
    
    @synchronized (self) {
        self.completionBlockEnable = YES;
        JXPlayerCacheToken *targetToken = nil;
        for (JXPlayerCacheToken *token in self.outputStreams) {
            if ([token.key isEqualToString:key]) {
                targetToken = token;
                break;
            }
        }
        if (!targetToken) {
            // 临时文件
            NSString *path = [JXPlayerCachePathTool videoCacheTemporaryPathForKey:key];
            /**!
             写入数据到输出流时，需要下面几个步骤:
             1.使用要写入的数据创建和初始化一个NSOutputStream实例，并设置代理对象
             2.将流对象放到run loop中并打开流
             3.处理流对象发送到代理对象中的事件
             4.如果流对象写入数据到内存，则通过请求NSStreamDataWrittenToMemoryStreamKey属性来获取数据
             5.当没有更多数据可供写入时，处理流对象
             */
            // 第一个参数:指向的路径 如果该路径下面文件不存在那么会自动创建一个空的
            // 第二个参数:追加
            NSOutputStream *stream = [[NSOutputStream alloc]initToFileAtPath:path append:YES];
            // 打开输出流
            [stream open];
            JXPlayerCacheToken *token = [JXPlayerCacheToken new];
            token.key = key;
            token.outputStream = stream;
            [self.outputStreams addObject:token];
            targetToken = token;
        }
        
        if (videoData.length>0) {
            dispatch_async(self.ioQueue, ^{
                // 使用写数据到磁盘
                [targetToken.outputStream write:videoData.bytes maxLength:videoData.length];
                targetToken.receivedVideoSize += videoData.length;
                
                NSString *tempVideoCachePath = [JXPlayerCachePathTool videoCacheTemporaryPathForKey:key];
                
                // transform to NSUrl
                NSURL *fileURL = [NSURL fileURLWithPath:tempVideoCachePath];
                
                // 用iCloud备份,默认为NO
                if (self.config.shouldDisableiCloud) {
                    [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
                }
                
                if (completionBlock) {
                    NSString *fullVideoCachePath = nil;
                    NSError *error = nil;
                    if (targetToken.receivedVideoSize == expectedSize) {
                        fullVideoCachePath = [JXPlayerCachePathTool videoCacheFullPathForKey:key];
                        [_fileManager moveItemAtPath:tempVideoCachePath toPath:fullVideoCachePath error:&error];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.completionBlockEnable) {
                            completionBlock(targetToken.receivedVideoSize, error, fullVideoCachePath);
                        }
                    });
                }
                
                // 完成
                // cache temporary video data finished.
                // close the stream.
                // remove the cache operation.
                if (targetToken.receivedVideoSize==expectedSize) {
                    [targetToken.outputStream close];// 关闭流
                    [self.outputStreams removeObject:targetToken]; // 移除操作
                    self.completionBlockEnable = NO;
                }
            });
        }
        return targetToken;
    }
}

- (void)cancel:(nullable JXPlayerCacheToken *)token{
    if (token) {
        [self.outputStreams removeObject:token];
        [self cancelCurrentComletionBlock];
    }
}

- (void)cancelCurrentComletionBlock{
    self.completionBlockEnable = NO;
}


#pragma mark - Query and Retrieve Options

- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key
                                               done:(nullable JXPlayerCacheQueryCompletedBlock)doneBlock {
    //如果对应的key为空，那么就直接返回
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, JXPlayerCacheTypeNone);
        }
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        //先判断该下载操作是否已经被取消
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }
        
        @autoreleasepool {
            BOOL exists = [_fileManager fileExistsAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key]];
            
            if (!exists) {
                exists = [_fileManager fileExistsAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key].stringByDeletingPathExtension];
            }
            
            if (exists) {
                if (doneBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock([JXPlayerCachePathTool videoCacheFullPathForKey:key], JXPlayerCacheTypeDisk);
                    });
                }
            }
            else{
                if (doneBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(nil, JXPlayerCacheTypeNone);
                    });
                }
            }
        }
    });
    
    return operation;
}

- (void)diskVideoExistsWithKey:(NSString *)key completion:(JXPlayerCheckCacheCompletionBlock)completionBlock{
    dispatch_async(_ioQueue, ^{
        BOOL exists = [_fileManager fileExistsAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key]];
        
        if (!exists) {
            exists = [_fileManager fileExistsAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key].stringByDeletingPathExtension];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskVideoExistsWithPath:(NSString * _Nullable)fullVideoCachePath{
    return [_fileManager fileExistsAtPath:fullVideoCachePath];
}


#pragma mark - Clear Cache Events

- (void)removeFullCacheForKey:(nullable NSString *)key withCompletion:(nullable JXPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        if ([_fileManager fileExistsAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key]]) {
            [_fileManager removeItemAtPath:[JXPlayerCachePathTool videoCacheFullPathForKey:key] error:nil];
            dispatch_main_async_safe(^{
                if (completion) {
                    completion();
                }
            });
        }
    });
}

- (void)removeTempCacheForKey:(NSString * _Nonnull)key withCompletion:(nullable JXPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        NSString *path = [JXPlayerCachePathTool videoCachePathForAllTemporaryFile];
        path = [path stringByAppendingPathComponent:[[JXPlayerCache sharedCache] cacheFileNameForKey:key]];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
            dispatch_main_async_safe(^{
                if (completion) {
                    completion();
                }
            });
            // For Test.
            // printf("Remove temp video data finished, file url string is %@", key);
        }
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable JXPlayerNoParamsBlock)completionBlock{
    // 异步计算磁盘缓存的大小
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:[JXPlayerCachePathTool videoCachePathForAllFullFile] isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // // 使用目录枚举器获取缓存文件的三个重要属性：(1)URL是否为目录；(2)内容最后更新日期；(3)文件总的分配大小。
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        // 计算过期时间
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        
        NSUInteger currentCacheSize = 0;
        
        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        
        @autoreleasepool {
            for (NSURL *fileURL in fileEnumerator) {
                NSError *error;
                NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
                
                // Skip directories and errors.
                if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                    continue;
                }
                
                // Remove files that are older than the expiration date;
                NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
                if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                    [urlsToDelete addObject:fileURL];
                    continue;
                }
                
                // Store a reference to this file and account for its total size.
                NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
                cacheFiles[fileURL] = resourceValues;
            }
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

- (void)deleteAllTempCacheOnCompletion:(nullable JXPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JXPlayerCachePathTool videoCachePathForAllTemporaryFile] error:nil];
        dispatch_main_async_safe(^{
            if (completion) {
                completion();
            }
        });
    });
}

- (void)clearDiskOnCompletion:(nullable JXPlayerNoParamsBlock)completion{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[JXPlayerCachePathTool videoCachePathForAllFullFile] error:nil];
        [_fileManager removeItemAtPath:[JXPlayerCachePathTool videoCachePathForAllTemporaryFile] error:nil];
        dispatch_main_async_safe(^{
            if (completion) {
                completion();
            }
        });
    });
}


#pragma mark - File Name

- (nullable NSString *)cacheFileNameForKey:(nullable NSString *)key{
    return [self cachedFileNameForKey:key];
}

- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    if ([key length]) {
        NSString *strippedQueryKey = [[NSURL URLWithString:key] absoluteStringByStrippingQuery];
        key = [strippedQueryKey length] ? strippedQueryKey : key;
    }
    //要进行UTF8的转码
    const char *str = key.UTF8String;
    if (str == NULL) str = "";
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *pathExtension = key.pathExtension.length > 0 ? [NSString stringWithFormat:@".%@", key.pathExtension] : @".mp4";
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], pathExtension];
    return filename;
}


#pragma mark - Cache Info
/// 判断是否还有足够的内存
- (BOOL)haveFreeSizeToCacheFileWithSize:(NSUInteger)fileSize{
    unsigned long long freeSizeOfDevice = [self getDiskFreeSize];
    if (fileSize > freeSizeOfDevice) {
        return NO;
    }
    return YES;
}

- (unsigned long long)getSize{
    __block unsigned long long size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempFilePath = [JXPlayerCachePathTool videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JXPlayerCachePathTool videoCachePathForAllFullFile];
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtPath:tempFilePath];
        
        @autoreleasepool {
            for (NSString *fileName in fileEnumerator_temp) {
                NSString *filePath = [tempFilePath stringByAppendingPathComponent:fileName];
                NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                size += [attrs fileSize];
            }
            
            NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtPath:fullFilePath];
            for (NSString *fileName in fileEnumerator_full) {
                NSString *filePath = [fullFilePath stringByAppendingPathComponent:fileName];
                NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                size += [attrs fileSize];
            }
        }
    });
    return size;
}

- (NSUInteger)getDiskCount{
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSString *tempFilePath = [JXPlayerCachePathTool videoCachePathForAllTemporaryFile];
        NSString *fullFilePath = [JXPlayerCachePathTool videoCachePathForAllFullFile];
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtPath:tempFilePath];
        count += fileEnumerator_temp.allObjects.count;
        
        NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtPath:fullFilePath];
        count += fileEnumerator_full.allObjects.count;
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(JXPlayerCalculateSizeBlock)completionBlock{
    
    NSString *tempFilePath = [JXPlayerCachePathTool videoCachePathForAllTemporaryFile];
    NSString *fullFilePath = [JXPlayerCachePathTool videoCachePathForAllFullFile];
    
    NSURL *diskCacheURL_temp = [NSURL fileURLWithPath:tempFilePath isDirectory:YES];
    NSURL *diskCacheURL_full = [NSURL fileURLWithPath:fullFilePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator_temp = [_fileManager enumeratorAtURL:diskCacheURL_temp includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_temp) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        NSDirectoryEnumerator *fileEnumerator_full = [_fileManager enumeratorAtURL:diskCacheURL_full includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator_full) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - 获取剩余存储空间
- (unsigned long long)getDiskFreeSize{
    struct statfs buf;
    unsigned long long freespace = -1;
    if(statfs("/var", &buf) >= 0){
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    // 手机剩余存储空间为
    return freespace;
}



@end
