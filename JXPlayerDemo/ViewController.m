//
//  ViewController.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "ViewController.h"
#import "UIView+WebVideoCache.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageVIew;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.imageVIew jx_playVideoWithURL:[NSURL URLWithString:@"http://static.smartisanos.cn/common/video/proud-farmer.mp4"]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
