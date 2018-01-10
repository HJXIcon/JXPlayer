//
//  UIView+WebVideoCacheOperation.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "UIView+WebVideoCacheOperation.h"
#import "JXPlayerOperation.h"
#import "objc/runtime.h"

static char loadOperationKey;
static char currentPlayingURLKey;

typedef NSMutableDictionary<NSString *, id> JXOperationsDictionary;

@implementation UIView (WebVideoCacheOperation)


#pragma mark - Public

- (void)setCurrentPlayingURL:(NSURL *)currentPlayingURL{
    objc_setAssociatedObject(self, &currentPlayingURLKey, currentPlayingURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)currentPlayingURL{
    return objc_getAssociatedObject(self, &currentPlayingURLKey);
}

- (void)jx_setVideoLoadOperation:(id)operation forKey:(NSString *)key{
    if (key) {
        [self jx_cancelVideoLoadOperationWithKey:key];
        if (operation) {
            JXOperationsDictionary *operationDictionary = [self operationDictionary];
            operationDictionary[key] = operation;
        }
    }
    
}

/**
 取消对应key的全部操作
 
 @param key key
 */
- (void)jx_cancelVideoLoadOperationWithKey:(NSString *)key{
    // Cancel in progress downloader from queue.
    JXOperationsDictionary *operationDictionary = [self operationDictionary];
    id operations = operationDictionary[key];
    if (operations) {
        if ([operations isKindOfClass:[NSArray class]]) {
            for (id <JXPlayerOperation> operation in operations) {
                if (operation) {
                    [operation cancel];
                }
            }
        }
        // 是用来检查对象（包括其祖先）是否实现了指定协议类的方法
        else if ([operations conformsToProtocol:@protocol(JXPlayerOperation)]){
            [(id<JXPlayerOperation>) operations cancel];
        }
        [operationDictionary removeObjectForKey:key];
    }
}

- (void)jx_removeVideoLoadOperationWithKey:(NSString *)key{
    if (key) {
        JXOperationsDictionary *operationDictionary = [self operationDictionary];
        [operationDictionary removeObjectForKey:key];
    }
}


#pragma mark - Private

- (JXOperationsDictionary *)operationDictionary {
    JXOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
    if (operations) {
        return operations;
    }
    operations = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return operations;
}


@end
