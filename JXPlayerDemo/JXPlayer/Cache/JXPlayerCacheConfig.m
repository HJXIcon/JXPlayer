//
//  JXPlayerCacheConfig.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerCacheConfig.h"

NSInteger const JXPlayerCacheConfigDefaultCacheMaxCacheAge = 60*60*24*7; // 1 week
NSInteger const JXPlayerCacheConfigDefaultCacheMaxSize = 1000*1000*1000; // 1 GB

@implementation JXPlayerCacheConfig

- (instancetype)init{
    self = [super init];
    if (self) {
        _maxCacheAge =  JXPlayerCacheConfigDefaultCacheMaxCacheAge;
        _maxCacheSize = JXPlayerCacheConfigDefaultCacheMaxSize;
    }
    return self;
}

@end
