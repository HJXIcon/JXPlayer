//
//  JXPlayerResourceLoader.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface JXPlayerResourceLoader()

@property (nonatomic, strong, nullable)NSMutableArray *pendingRequests;

@property(nonatomic, assign)NSUInteger expectedSize;

@property(nonatomic, assign)NSUInteger receivedSize;

@property(nonatomic, strong, nullable)NSString *tempCacheVideoPath;

@end
static NSString *JPVideoPlayerMimeType = @"video/mp4";

@implementation JXPlayerResourceLoader
- (instancetype)init{
    self = [super init];
    if (self) {
        self.pendingRequests = [NSMutableArray array];
    }
    return self;
}
#pragma mark - Public

- (void)didReceivedDataCacheInDiskByTempPath:(NSString * _Nonnull)tempCacheVideoPath videoFileExceptSize:(NSUInteger)expectedSize videoFileReceivedSize:(NSUInteger)receivedSize{
    self.tempCacheVideoPath = tempCacheVideoPath;
    self.expectedSize = expectedSize;
    self.receivedSize = receivedSize;
    
    [self internalPendingRequests];
}

- (void)didCachedVideoDataFinishedFromWebFullVideoCachePath:(NSString * _Nullable)fullVideoCachePath{
    self.tempCacheVideoPath = fullVideoCachePath;
    self.receivedSize = self.expectedSize;
    [self internalPendingRequests];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    if (resourceLoader && loadingRequest){
        [self.pendingRequests addObject:loadingRequest];
        [self internalPendingRequests];
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    [self.pendingRequests removeObject:loadingRequest];
}


#pragma mark - Private

- (void)internalPendingRequests{
    
    // Enumerate all loadingRequest
    // For every singal loadingRequest, combine response-data length and file mimeType
    // Then judge the download file data is contain the loadingRequest's data or not, if Yes, take out the request's data and return to loadingRequest, next to colse this loadingRequest. if No, continue wait for download finished.
    
    NSError *error;
    NSData *tempVideoData = [NSData dataWithContentsOfFile:_tempCacheVideoPath options:NSDataReadingMappedIfSafe error:&error];
    if (!error) {
        NSMutableArray *requestsCompleted = [NSMutableArray array];
        @autoreleasepool {
            for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
                [self fillInContentInformation:loadingRequest.contentInformationRequest];
                
                BOOL didRespondFinished = [self respondWithDataForRequest:loadingRequest andTempVideoData:tempVideoData];
                if (didRespondFinished) {
                    [requestsCompleted addObject:loadingRequest];
                    [loadingRequest finishLoading];
                }
            }
        }
        if (requestsCompleted.count) {
            [self.pendingRequests removeObjectsInArray:[requestsCompleted copy]];
        }
    }
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingRequest *)loadingRequest andTempVideoData:(NSData * _Nullable)tempVideoData{
    
    // Thanks for @DrunkenMouse(http://www.jianshu.com/users/5d853d21f7da/latest_articles) submmit a bug that my mistake of calculate "endOffset".
    // Thanks for Nick Xu Mark.
    
    AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
    
    NSUInteger startOffset = (NSUInteger)dataRequest.requestedOffset;
    if (dataRequest.currentOffset!=0) {
        startOffset = (NSUInteger)dataRequest.currentOffset;
    }
    startOffset = MAX(0, startOffset);
    
    // Don't have any data at all for this reques
    if (self.receivedSize<startOffset) {
        return NO;
    }
    
    NSUInteger unreadBytes = self.receivedSize - startOffset;
    unreadBytes = MAX(0, unreadBytes);
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    NSRange respondRange = NSMakeRange(startOffset, numberOfBytesToRespondWith);
    if (tempVideoData.length>=numberOfBytesToRespondWith) {
        [dataRequest respondWithData:[tempVideoData subdataWithRange:respondRange]];
    }
    
    long long endOffset = startOffset + dataRequest.requestedLength;
    
    // if the received data greater than the requestLength.
    if (_receivedSize >= endOffset) {
        return YES;
    }
    // if the received data less than the requestLength.
    return NO;
}


// 填充响应数据
- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest * _Nonnull)contentInformationRequest{
    if (contentInformationRequest) {
        NSString *mimetype = JPVideoPlayerMimeType;
        // http://blog.csdn.net/qq_30513483/article/details/51820538
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef _Nonnull)(mimetype), NULL);
        contentInformationRequest.byteRangeAccessSupported = YES;
        contentInformationRequest.contentType = CFBridgingRelease(contentType);
        contentInformationRequest.contentLength = self.expectedSize;
    }
}

@end
