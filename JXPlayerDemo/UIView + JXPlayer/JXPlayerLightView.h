//
//  JXPlayerLightView.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/8.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JXPlayerLightView : UIView

@property (strong, nonatomic)  UIView *lightBackView;
@property (strong, nonatomic)  UIImageView *centerLightIV;

@property (nonatomic, strong) NSMutableArray *lightViewArr;

+ (instancetype)sharedLightView;

@end
