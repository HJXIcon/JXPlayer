//
//  JXPlayerDownloader.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, JXPlayerDownloaderOptions) {
    /*
     * 如果图像是从 NSURLCache 读取的，则调用 completion block 时，image/imageData 传入 nil
     * (此标记要和 `SDWebImageDownloaderUseNSURLCache` 组合使用)
     */
    JXPlayerDownloaderIgnoreCachedResponse = 1 << 0,
    /*
     * 在 iOS 4+，当 App 进入后台后仍然会继续下载图像。这是向系统请求额外的后台时间以保证下载请求完成的
     * 如果后台任务过期，请求将会被取消
     */
    JXPlayerDownloaderContinueInBackground = 1 << 1,
    /*
     *  处理保存在 NSHTTPCookieStore 中的 cookies
     */
    JXPlayerDownloaderHandleCookies = 1 << 2,
    /*
     * 允许不信任的 SSL 证书
     * 可以出于测试目的使用，在正式产品中慎用
     */
    JXPlayerDownloaderAllowInvalidSSLCertificates = 1 << 3,
    // 显示进度
    JXPlayerDownloaderShowProgressView = 1 << 4,
    // 转菊花
    JXPlayerDownloaderShowActivityIndicatorView = 1 << 5,
};

typedef void(^JXPlayerDownloaderProgressBlock)(NSData * _Nullable data, NSInteger receivedSize, NSInteger expectedSize, NSString *_Nullable tempCachedVideoPath, NSURL * _Nullable targetURL);

typedef void(^JXPlayerDownloaderErrorBlock)(NSError *_Nullable error);

typedef NSDictionary<NSString *, NSString *> JXHTTPHeadersDictionary;

typedef NSMutableDictionary<NSString *, NSString *> JXHTTPHeadersMutableDictionary;

typedef JXHTTPHeadersDictionary * _Nullable (^JXPlayerDownloaderHeadersFilterBlock)(NSURL * _Nullable url, JXHTTPHeadersDictionary * _Nullable headers);

#pragma mark - *** JXPlayerDownloadToken
@interface JXPlayerDownloadToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;

@property (nonatomic, strong, nullable) id downloadOperationCancelToken;

@end

#pragma mark - *** JXPlayerDownloader
/**
 下载工具类，管理下载操作队列
 */
@interface JXPlayerDownloader : NSObject
// 设置默认的URL身份认证信息
@property (strong, nonatomic, nullable) NSURLCredential *urlCredential;
// 设置用户名
@property (strong, nonatomic, nullable) NSString *username;
// 设置密码
@property (strong, nonatomic, nullable) NSString *password;

/*
 * 设置下载图像 HTTP 请求头过滤器
 * 此 block 将被每一个下载图像的请求调用，返回的 NSDictionary 将被作为相应的 HTTP 请求头
 */
@property (nonatomic, copy, nullable) JXPlayerDownloaderHeadersFilterBlock headersFilter;

/**
 下载操作的超时时长(秒)，默认：15秒
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;

// 单例方法，返回一个全局共享的下载器
+ (nonnull instancetype)sharedDownloader;
/*
 * 为 HTTP 请求头设置一个值
 * value 请求头字段的值，使用 `nil` 删除该字段
 * field 要设置的请求头字段名
 */
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;
/*
 * 返回指定 HTTP 请求头字段的值
 * 返回值为请求头字段的值，如果没有返回 `nil`
 */
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;

/**
 配置参数

 @param sessionConfiguration NSURLSessionConfiguration
 @return JXPlayerDownloader
 */
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/*
 * 使用给定的 URL 创建 JXPlayerDownloader 异步下载器实例
 * 视频下载完成或者出现错误时会通知代理
 * url:要下载的视频 URL
 * JXPlayerDownloaderOptions：下载选项|策略
 * progressBlock 视频下载过程中被重复调用的 block，用来报告下载进度
 * completedBlock：视频下载完成后被调用一次的 block
 *  返回值：可被取消的 JXPlayerDownloadToken
 */
- (nullable JXPlayerDownloadToken *)downloadVideoWithURL:(nullable NSURL *)url options:(JXPlayerDownloaderOptions)options progress:(nullable JXPlayerDownloaderProgressBlock)progressBlock completed:(nullable JXPlayerDownloaderErrorBlock)errorBlock;

/**
 取消JXPlayerDownloadToken

 @param token 可被取消的JXPlayerDownloadToken
 */
- (void)cancel:(nullable JXPlayerDownloadToken *)token;

/**
 取消全部
 */
- (void)cancelAllDownloads;
@end
