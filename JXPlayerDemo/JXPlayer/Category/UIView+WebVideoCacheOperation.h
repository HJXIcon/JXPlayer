//
//  UIView+WebVideoCacheOperation.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 缓存操作
 */
@interface UIView (WebVideoCacheOperation)

/**
 当前播放URL
 */
@property(nonatomic, nullable)NSURL *currentPlayingURL;

/**
 设置操作

 @param operation 一个或者多个操作
 @param key key
 */
- (void)jx_setVideoLoadOperation:(nullable id)operation forKey:(nullable NSString *)key;

/**
 取消对应key的全部操作

 @param key key
 */
- (void)jx_cancelVideoLoadOperationWithKey:(nullable NSString *)key;

/**
 移除对应key的操作

 @param key key
 */
- (void)jx_removeVideoLoadOperationWithKey:(nullable NSString *)key;

@end
