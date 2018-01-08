//
//  JXPlayerCachePathTool.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSString * _Nonnull const JPVideoPlayerCacheVideoPathForTemporaryFile;
extern NSString * _Nonnull const JPVideoPlayerCacheVideoPathForFullFile;

/**
 管理临时和完整视频存储路径
 */
@interface JXPlayerCachePathTool : NSObject


/**
 获取所有的临时文件所在的文件夹路径

 @return 文件夹路径
 */
+ (nonnull NSString *)videoCachePathForAllTemporaryFile;

/**
 获取所有的完整文件所在的文件夹路径

 @return 文件夹路径
 */
+ (nonnull NSString *)videoCachePathForAllFullFile;

/**
 获取指定key的临时文件所在的文件夹路径

 @param key 指定的键
 @return 文件夹路径
 */
+ (nonnull NSString *)videoCacheTemporaryPathForKey:( NSString * _Nonnull )key;

/**
 获取指定key缓存的视频所在的文件夹路径
 
 @param key 指定的键
 @return 文件夹路径
 */
+ (nonnull NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key;

@end
