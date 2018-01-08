//
//  JXPlayerCache.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JXPlayerCacheConfig.h"

typedef NS_ENUM(NSInteger, JXPlayerCacheType) {
    JXPlayerCacheTypeNone,
    JXPlayerCacheTypeDisk, 
    JXPlayerCacheTypeLocation
};

typedef void(^JXPlayerCacheQueryCompletedBlock)(NSString * _Nullable videoPath, JXPlayerCacheType cacheType);

typedef void(^JXPlayerCheckCacheCompletionBlock)(BOOL isInDiskCache);

typedef void(^JXPlayerCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);

typedef void(^JXPlayerNoParamsBlock)(void);

typedef void(^JXPlayerStoreDataFinishedBlock)(NSUInteger storedSize, NSError * _Nullable error, NSString * _Nullable fullVideoCachePath);

#pragma mark - *** JXPlayerCacheToken
/**
 输出流信息：输出流、视频保存的key、已经接收写入的的二进制文件大小
 */
@interface JXPlayerCacheToken : NSObject

@end


#pragma mark - *** JXPlayerCache

/**
 缓存工具类，负责视频数据的存、取、删、更新
 */
@interface JXPlayerCache : NSObject

#pragma mark - Singleton and initialization

@property (nonatomic, nonnull, readonly)JXPlayerCacheConfig *config;

+ (nonnull instancetype)sharedCache;


# pragma mark - Store Video Options

/**
 存储视频到文件夹

 @param videoData 视频二进制文件
 @param expectedSize 视频二进制文件期待大小
 @param key 指定的键
 @param completionBlock 完成回调block
 @return JXPlayerCacheToken
 */
- (nullable JXPlayerCacheToken *)storeVideoData:(nullable NSData *)videoData expectedSize:(NSUInteger)expectedSize forKey:(nullable NSString *)key completion:(nullable JXPlayerStoreDataFinishedBlock)completionBlock;

/**
 取消视频写入

 @param token 对应的输出流信息token
 */
- (void)cancel:(nullable JXPlayerCacheToken *)token;


/**
 取消当前的block回调
 */
- (void)cancelCurrentComletionBlock;


# pragma - Query and Retrieve Options

/**
 查找当前视频是否存在

 @param key 指定的键
 @param completionBlock 回调block
 */
- (void)diskVideoExistsWithKey:(nullable NSString *)key completion:(nullable JXPlayerCheckCacheCompletionBlock)completionBlock;

/**
 查询当前操作是否存在

 @param key 指定的键
 @param doneBlock 回调block
 @return 操作
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable JXPlayerCacheQueryCompletedBlock)doneBlock;


/**
 当前路径是否存在

 @param fullVideoCachePath 路径
 */
- (BOOL)diskVideoExistsWithPath:(NSString * _Nullable)fullVideoCachePath;


# pragma mark - Clear Cache Events

/**
 移除视频文件

 @param key 指定的键
 @param completion 回调block
 */
- (void)removeFullCacheForKey:(nullable NSString *)key withCompletion:(nullable JXPlayerNoParamsBlock)completion;

/**
 移除视频的临时文件

 @param key 指定的键
 @param completion 回调block
 */
- (void)removeTempCacheForKey:(NSString * _Nonnull)key withCompletion:(nullable JXPlayerNoParamsBlock)completion;

/**
 删除过期视频文件

 @param completionBlock 回调block
 */
- (void)deleteOldFilesWithCompletionBlock:(nullable JXPlayerNoParamsBlock)completionBlock;


/**
 删除视频所有的临时文件

 @param completion 回调block
 */
- (void)deleteAllTempCacheOnCompletion:(nullable JXPlayerNoParamsBlock)completion;


/**
 清除全部视频本地文件

 @param completion 回调block
 */
- (void)clearDiskOnCompletion:(nullable JXPlayerNoParamsBlock)completion;


# pragma mark - Cache Info

/**
 判断是否还有足够的内存

 @param fileSize 需要存储的内存大小
 */
- (BOOL)haveFreeSizeToCacheFileWithSize:(NSUInteger)fileSize;

/**
 获取剩余存储空间

 @return 剩余存储空间大小
 */
- (unsigned long long)getDiskFreeSize;

/**
 获取当前缓存大小

 @return 缓存大小
 */
- (unsigned long long)getSize;

/**
 获取缓存文件个数

 @return  缓存文件个数
 */
- (NSUInteger)getDiskCount;

/**
 异步计算磁盘缓存的大小

 @param completionBlock 回调block
 */
- (void)calculateSizeWithCompletionBlock:(nullable JXPlayerCalculateSizeBlock)completionBlock;

# pragma mark - File Name

/**
 缓存文件名

 @param key 指定的键
 @return 缓存文件名称
 */
- (nullable NSString *)cacheFileNameForKey:(nullable NSString *)key;

@end
