//
//  JXPlayerCachePathTool.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayerCachePathTool.h"
#import "JXPlayerCache.h"

NSString * const JXPlayerCacheVideoPathForTemporaryFile = @"/TemporaryFile";
NSString * const JXPlayerCacheVideoPathForFullFile = @"/FullFile";


@implementation JXPlayerCachePathTool

#pragma mark - Public

+(nonnull NSString *)videoCachePathForAllTemporaryFile{
    return [self getFilePathWithAppendingString:JXPlayerCacheVideoPathForTemporaryFile];
}

+(nonnull NSString *)videoCachePathForAllFullFile{
    return [self getFilePathWithAppendingString:JXPlayerCacheVideoPathForFullFile];
}

// 临时文件
+(nonnull NSString *)videoCacheTemporaryPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self videoCachePathForAllTemporaryFile];
    if (path.length!=0) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        path = [path stringByAppendingPathComponent:[[JXPlayerCache sharedCache] cacheFileNameForKey:key]];
        if (![fileManager fileExistsAtPath:path]) {
            [fileManager createFileAtPath:path contents:nil attributes:nil];
            // For Test
            // printf("Create temporary file");
        }
    }
    return path;
}

+(nonnull NSString *)videoCacheFullPathForKey:(NSString * _Nonnull)key{
    NSString *path = [self videoCachePathForAllFullFile];
    path = [path stringByAppendingPathComponent:[[JXPlayerCache sharedCache] cacheFileNameForKey:key]];
    return path;
}


#pragma mark - Private

+(nonnull NSString *)getFilePathWithAppendingString:(nonnull NSString *)apdStr{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingString:apdStr];
    
    if (![fileManager fileExistsAtPath:path])
    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    return path;
}

/**!
 1、Documents 目录：您应该将所有的应用程序数据文件写入到这个目录下。这个目录用于存储用户数据或其它应该定期备份的信息。为了不让App的备份过于庞大，我们不建议在这里存放大容量的文件。
 2、AppName.app 目录：这是应用程序的程序包目录，包含应用程序的本身。由于应用程序必须经过签名，所以您在运行时不能对这个目录中的内容进行修改，否则可能会使应用程序无法启动。
 3、Library 目录：这个目录下有两个子目录：Caches 和 Preferences
 Preferences 目录：包含应用程序的偏好设置文件。您不应该直接创建偏好设置文件，而是应该使用NSUserDefaults类来取得和设置应用程序的偏好.
 Caches 目录：用于存放应用程序专用的支持文件，保存应用程序再次启动过程中需要的信息。细心的话你会发现几乎所有的第三方框架的缓存信息处理都在这个文件中，一般的大容量文件都放在这里。
 4、tmp 目录：这个目录用于存放临时文件，保存应用程序再次启动过程中不需要的信息。Nsuserdefaults保存的文件一般在tmp文件夹里。
 */

/***!
 1，获取家目录路径的函数：
 NSString *homeDir = NSHomeDirectory();
 
 2，获取Documents目录路径的方法：
 NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
 NSString *docDir = [paths objectAtIndex:0];
 
 3，获取Caches目录路径的方法：
 NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
 NSString *cachesDir = [paths objectAtIndex:0];
 
 4，获取tmp目录路径的方法：
 NSString *tmpDir = NSTemporaryDirectory();
 */

@end
