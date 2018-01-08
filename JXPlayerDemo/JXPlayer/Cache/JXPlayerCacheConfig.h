//
//  JXPlayerCacheConfig.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSInteger const JXPlayerCacheConfigDefaultCacheMaxCacheAge;
extern NSInteger const JXPlayerCacheConfigDefaultCacheMaxSize;

/**
 缓存配置文件，包括缓存周期，最大磁盘缓存等
 */
@interface JXPlayerCacheConfig : NSObject

/**
 缓存的最长时间，以秒为单位，默认为1周
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 缓存图像总大小，以字节为单位，默认1 GB
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

/**
 * 用iCloud备份,默认为NO
 */
@property (assign, nonatomic) BOOL shouldDisableiCloud;

@end
