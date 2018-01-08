//
//  NSURL+StripQuery.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "NSURL+StripQuery.h"

@implementation NSURL (StripQuery)

- (NSString *)absoluteStringByStrippingQuery{
    
    NSString *absoluteString = [self absoluteString];
    NSUInteger queryLength = [[self query] length];
    NSString* strippedString = (queryLength ? [absoluteString substringToIndex:[absoluteString length] - (queryLength + 1)] : absoluteString);
    
    if ([strippedString hasSuffix:@"?"]) {
        strippedString = [strippedString substringToIndex:absoluteString.length-1];
    }
    return strippedString;
}

@end
