//
//  NSURL+StripQuery.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (StripQuery)

- (NSString *)absoluteStringByStrippingQuery;

@end
