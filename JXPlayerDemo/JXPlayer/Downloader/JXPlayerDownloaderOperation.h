//
//  JXPlayerDownloaderOperation.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//
/**!
 自定义并发的NSOperation需要以下步骤：
 1.start方法：该方法必须实现，
 2.main:该方法可选，如果你在start方法中定义了你的任务，则这个方法就可以不实现，但通常为了代码逻辑清晰，通常会在该方法中定                         义自己的任务
 3.isExecuting  isFinished 主要作用是在线程状态改变时，产生适当的KVO通知
 4.isConcurrent :必须覆盖并返回YES;
 */

#import <UIKit/UIKit.h>
#import "JXPlayerDownloader.h"

extern NSString * _Nonnull const JXPlayerDownloadStartNotification;
extern NSString * _Nonnull const JXPlayerDownloadReceiveResponseNotification;
extern NSString * _Nonnull const JXPlayerDownloadStopNotification;
extern NSString * _Nonnull const JXPlayerDownloadFinishNotification;

/**
 自定义NSOperation:下载单个视频文件工具
 */
@interface JXPlayerDownloaderOperation : NSOperation<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
/*
 * 请求对象
 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;
/*
 * 请求任务
 */
@property (strong, nonatomic, readonly, nullable) NSURLSessionTask *dataTask;

/*
 * 在 `-connection:didReceiveAuthenticationChallenge:` 方法中身份验证使用的凭据
 * 如果存在请求 URL 的用户名或密码的共享凭据，此凭据会被覆盖
 */
@property (nonatomic, strong, nullable) NSURLCredential *credential;

/*
 * 下载选项
 */
@property (assign, nonatomic, readonly) JXPlayerDownloaderOptions options;

/*
 * 请求数据的期望大小（视频的大小）
 */
@property (assign, nonatomic) NSUInteger expectedSize;

/*
 * 网络请求的响应头信息
 */
@property (strong, nonatomic, nullable) NSURLResponse *response;

/*
 * 初始化一个 `JXPlayerDownloaderOperation` 对象
 */
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request inSession:(nullable NSURLSession *)session options:(JXPlayerDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

- (nullable id)addHandlersForProgress:(nullable JXPlayerDownloaderProgressBlock)progressBlock error:(nullable JXPlayerDownloaderErrorBlock)errorBlock;

- (BOOL)cancel:(nullable id)token;

@end
