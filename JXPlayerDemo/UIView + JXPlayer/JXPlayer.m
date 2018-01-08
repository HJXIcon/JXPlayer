//
//  JXPlayer.m
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/8.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

#import "JXPlayer.h"
#import <Masonry/Masonry.h>
#import "JXPlayerLightView.h"

#define JXPlayerSrcName(file) [@"JXPlayer.bundle" stringByAppendingPathComponent:file]
#define JXPlayerFrameworkSrcName(file) [@"Frameworks/JXPlayer.framework/JXPlayer.bundle" stringByAppendingPathComponent:file]
#define JXPlayerImage(file)      [UIImage imageNamed:JXPlayerSrcName(file)] ? :[UIImage imageNamed:JXPlayerFrameworkSrcName(file)]


@interface JXPlayer () <UIGestureRecognizerDelegate>{
    //用来判断手势是否移动过
    BOOL _hasMoved;
    //记录触摸开始时的视频播放的时间
    float _touchBeginValue;
    //记录触摸开始亮度
    float _touchBeginLightValue;
    //记录触摸开始的音量
    float _touchBeginVoiceValue;
    
    //总时间
    CGFloat totalTime;
}

/** 是否初始化了播放器 */
@property (nonatomic, assign) BOOL isInitPlayer;

///记录touch开始的点
@property (nonatomic,assign)CGPoint touchBeginPoint;

///手势控制的类型
///判断当前手势是在控制进度?声音?亮度?
@property (nonatomic, assign) JXControlType controlType;

@property (nonatomic, strong)NSDateFormatter *dateFormatter;
//监听播放起状态的监听者
@property (nonatomic ,strong) id playbackTimeObserver;

//视频进度条的单击事件
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) BOOL isDragingSlider;//是否点击了按钮的响应事件
/**
 *  显示播放时间的UILabel
 */
@property (nonatomic,strong) UILabel *leftTimeLabel;
@property (nonatomic,strong) UILabel *rightTimeLabel;
///进度滑块
@property (nonatomic,strong) UISlider *progressSlider;
///声音滑块
@property (nonatomic,strong) UISlider *volumeSlider;
//显示缓冲进度
@property (nonatomic,strong) UIProgressView *loadingProgress;

@end

@implementation JXPlayer{
    UITapGestureRecognizer *singleTap;
}


#pragma mark - Lazy load
- (UILabel *)loadFailedLabel{
    if (_loadFailedLabel == nil) {
        _loadFailedLabel = [[UILabel alloc]init];
        _loadFailedLabel.backgroundColor = [UIColor clearColor];
        _loadFailedLabel.textColor = [UIColor whiteColor];
        _loadFailedLabel.textAlignment = NSTextAlignmentCenter;
        _loadFailedLabel.text = @"视频加载失败";
        _loadFailedLabel.hidden = YES;
        [self.contentView addSubview:_loadFailedLabel];
        
        [_loadFailedLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self.contentView);
            make.width.equalTo(self.contentView);
            make.height.equalTo(@30);
        }];
    }
    return _loadFailedLabel;
}


#pragma mark - init
- (void)awakeFromNib
{
    [self initPlayer];
    [super awakeFromNib];
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self initPlayer];
    }
    return self;
}

- (void)initPlayer{
    NSError *setCategoryErr = nil;
    NSError *activationErr  = nil;
    //后台播放
    [[AVAudioSession sharedInstance]
     setCategory: AVAudioSessionCategoryPlayback
     error: &setCategoryErr];
    //静音状态下播放
    [[AVAudioSession sharedInstance]
     setActive: YES
     error: &activationErr];
    
    // player内部的一个view，用来管理子视图
    self.contentView = [[UIView alloc]init];
    self.contentView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    // 创建fastForwardView
    
    // lightView
    [[UIApplication sharedApplication].keyWindow addSubview:[JXPlayerLightView sharedLightView]];
    
    //设置默认值
    self.seekTime = 0.00;
    self.enableVolumeGesture = YES;
    self.enableFastForwardGesture = YES;
    
    
    //小菊花
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    //    UIActivityIndicatorViewStyleWhiteLarge 的尺寸是（37，37）
    //    UIActivityIndicatorViewStyleWhite 的尺寸是（22，22）
    [self.contentView addSubview:self.loadingView];
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.contentView);
    }];
    [self.loadingView startAnimating];
    
    // 顶部操作工具栏
    self.topView = [[UIImageView alloc]init];
    self.topView.image = JXPlayerImage(@"top_shadow");
    self.topView.userInteractionEnabled = YES;
    //    self.topView.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.4];
    [self.contentView addSubview:self.topView];
    //autoLayout topView
    [self.topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).with.offset(0);
        make.right.equalTo(self.contentView).with.offset(0);
        make.height.mas_equalTo(70);
        make.top.equalTo(self.contentView).with.offset(0);
    }];
    
    
    // 底部操作工具栏
    self.bottomView = [[UIImageView alloc]init];
    self.bottomView.image = JXPlayerImage(@"bottom_shadow");
    self.bottomView.userInteractionEnabled = YES;
    //    self.bottomView.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.4];
    [self.contentView addSubview:self.bottomView];
    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).with.offset(0);
        make.right.equalTo(self.contentView).with.offset(0);
        make.height.mas_equalTo(50);
        make.bottom.equalTo(self.contentView).with.offset(0);
    }];
    
    // 如果视图的autoresizesSubviews属性声明被设置为YES，则其子视图会根据autoresizingMask属性的值自动进行尺寸调整
    [self setAutoresizesSubviews:NO];
    
    // 播放|暂停按钮
    self.playOrPauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playOrPauseBtn.showsTouchWhenHighlighted = YES;
    [self.playOrPauseBtn addTarget:self action:@selector(PlayOrPause:) forControlEvents:UIControlEventTouchUpInside];
    [self.playOrPauseBtn setImage:JXPlayerImage(@"pause") forState:UIControlStateNormal];
    [self.playOrPauseBtn setImage:JXPlayerImage(@"play") forState:UIControlStateSelected];
    [self.bottomView addSubview:self.playOrPauseBtn];
    [self.playOrPauseBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(0);
        make.height.mas_equalTo(50);
        make.bottom.equalTo(self.bottomView).with.offset(0);
        make.width.mas_equalTo(50);
        
    }];
    self.playOrPauseBtn.selected = YES;//默认状态，即默认是不自动播放
    
    // 调整系统屏幕亮度和音量
    MPVolumeView *volumeView = [[MPVolumeView alloc]init];
    for (UIControl *view in volumeView.subviews) {
        if ([view.superclass isSubclassOfClass:[UISlider class]]) {
            self.volumeSlider = (UISlider *)view;
        }
    }
    
    //slider
    self.progressSlider = [[UISlider alloc]init];
    self.progressSlider.minimumValue = 0.0;
    self.progressSlider.maximumValue = 1.0;
    [self.progressSlider setThumbImage:JXPlayerImage(@"dot")  forState:UIControlStateNormal];
    self.progressSlider.minimumTrackTintColor = [UIColor greenColor];
    self.progressSlider.maximumTrackTintColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    
    self.progressSlider.value = 0.0;//指定初始值
    //进度条的拖拽事件
    [self.progressSlider addTarget:self action:@selector(stratDragSlide:)  forControlEvents:UIControlEventValueChanged];
    //进度条的点击事件
    [self.progressSlider addTarget:self action:@selector(updateProgress:) forControlEvents:UIControlEventTouchUpInside];
    
    //给进度条添加单击手势
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    self.tap.delegate = self;
    [self.progressSlider addGestureRecognizer:self.tap];
    [self.bottomView addSubview:self.progressSlider];
    self.progressSlider.backgroundColor = [UIColor clearColor];
    //autoLayout slider
    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.centerY.equalTo(self.bottomView.mas_centerY).offset(-1);
        make.height.mas_equalTo(30);
    }];
    
    // 显示缓冲进度
    self.loadingProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.loadingProgress.progressTintColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5];
    self.loadingProgress.trackTintColor    = [UIColor clearColor];
    [self.bottomView addSubview:self.loadingProgress];
    [self.loadingProgress setProgress:0.0 animated:NO];
    [self.loadingProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.centerY.equalTo(self.bottomView.mas_centerY);
    }];
    
    [self.bottomView sendSubviewToBack:self.loadingProgress];
    
    // 控制全屏的按钮
    self.fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullScreenBtn.showsTouchWhenHighlighted = YES;
    [self.fullScreenBtn addTarget:self action:@selector(fullScreenAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.fullScreenBtn setImage:JXPlayerImage(@"fullscreen") forState:UIControlStateNormal];
    [self.fullScreenBtn setImage:JXPlayerImage(@"nonfullscreen") forState:UIControlStateSelected];
    [self.bottomView addSubview:self.fullScreenBtn];

    [self.fullScreenBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView).with.offset(0);
        make.height.mas_equalTo(50);
        make.bottom.equalTo(self.bottomView).with.offset(0);
        make.width.mas_equalTo(50);
        
    }];
    
    // leftTimeLabel显示左边的时间进度
    self.leftTimeLabel = [[UILabel alloc]init];
    self.leftTimeLabel.textAlignment = NSTextAlignmentLeft;
    self.leftTimeLabel.textColor = [UIColor whiteColor];
    self.leftTimeLabel.backgroundColor = [UIColor clearColor];
    self.leftTimeLabel.font = [UIFont systemFontOfSize:11];
    [self.bottomView addSubview:self.leftTimeLabel];
    
    [self.leftTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.height.mas_equalTo(20);
        make.bottom.equalTo(self.bottomView).with.offset(0);
    }];
    self.leftTimeLabel.text = [self convertTime:0.0];//设置默认值
    
    
    // rightTimeLabel显示右边的总时间
    self.rightTimeLabel = [[UILabel alloc]init];
    self.rightTimeLabel.textAlignment = NSTextAlignmentRight;
    self.rightTimeLabel.textColor = [UIColor whiteColor];
    self.rightTimeLabel.backgroundColor = [UIColor clearColor];
    self.rightTimeLabel.font = [UIFont systemFontOfSize:11];
    [self.bottomView addSubview:self.rightTimeLabel];
    
    [self.rightTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.height.mas_equalTo(20);
        make.bottom.equalTo(self.bottomView).with.offset(0);
    }];
    self.rightTimeLabel.text = [self convertTime:0.0];//设置默认值
    
    //_closeBtn
    _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeBtn.showsTouchWhenHighlighted = YES;
    //    _closeBtn.backgroundColor = [UIColor redColor];
    [_closeBtn addTarget:self action:@selector(colseTheVideo:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:_closeBtn];
    //autoLayout _closeBtn
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topView).with.offset(5);
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(30);
        make.top.equalTo(self.topView).with.offset(20);
        
    }];
    
    //titleLabel
    self.titleLabel = [[UILabel alloc]init];
    //    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [self.topView addSubview:self.titleLabel];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topView).with.offset(45);
        make.right.equalTo(self.topView).with.offset(-45);
        make.center.equalTo(self.topView);
        make.top.equalTo(self.topView).with.offset(0);
        
    }];
    
    
    // 单击的 Recognizer
    singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1; // 单击
    singleTap.numberOfTouchesRequired = 1;
    [self.contentView addGestureRecognizer:singleTap];
    
    // 双击的 Recognizer
    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTouchesRequired = 1; //手指数
    doubleTap.numberOfTapsRequired = 2; // 双击
    // 解决点击当前view时候响应其他控件事件
    [singleTap setDelaysTouchesBegan:YES];
    [doubleTap setDelaysTouchesBegan:YES];
    [singleTap requireGestureRecognizerToFail:doubleTap];//如果双击成立，则取消单击手势（双击的时候不回走单击事件）
    [self.contentView addGestureRecognizer:doubleTap];
    
    
    /// 监听通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appwillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
}

- (void)layoutSubviews{
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;
}

- (void)dealloc{
    for (UIView *aLightView in [UIApplication sharedApplication].keyWindow.subviews) {
        if ([aLightView isKindOfClass:[JXPlayerLightView class]]) {
            [aLightView removeFromSuperview];
        }
    }
    NSLog(@"JXPlayer dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player pause];
    [self.player removeTimeObserver:self.playbackTimeObserver];
    
    //移除观察者
    [_currentItem removeObserver:self forKeyPath:@"status"];
    [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [_currentItem removeObserver:self forKeyPath:@"duration"];
    
    _currentItem = nil;
    
    [self.effectView removeFromSuperview];
    self.effectView = nil;
    [self.playerLayer removeFromSuperlayer];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.player = nil;
    self.playOrPauseBtn = nil;
    self.playerLayer = nil;
    self.autoDismissTimer = nil;
}

#pragma mark - Notification Actions
- (void)appwillResignActive:(NSNotification *)note{
    
}

- (void)appBecomeActive:(NSNotification *)note{
    
}
/// 进入前台
- (void)appWillEnterForeground:(NSNotification*)note
{
    if (self.playOrPauseBtn.isSelected == NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.frame = self.contentView.bounds;
        self.playerLayer.videoGravity = AVLayerVideoGravityResize;
        [self.contentView.layer insertSublayer:_playerLayer atIndex:0];
        [self.player play];
        self.state = JXPlayerStatePlaying;
        NSLog(@"3333333%s JXPlayerStatePlaying",__FUNCTION__);
        
    }else{
        NSLog(@"%s JXPlayerStateStopped",__FUNCTION__);
        
        self.state = JXPlayerStateStopped;
    }
}
/// 进入后台
- (void)appDidEnterBackground:(NSNotification*)note{
    
    if (self.playOrPauseBtn.isSelected == NO) {//如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        self.playerLayer.player = nil;
        [self.player play];
        NSLog(@"22222 %s JXPlayerStatePlaying",__FUNCTION__);
        
        self.state = JXPlayerStatePlaying;
    }else{
        NSLog(@"%s JXPlayerStateStopped",__FUNCTION__);
        self.state = JXPlayerStateStopped;
    }
}


#pragma mark - Actions
#pragma mark *** 双击
- (void)handleDoubleTap:(UIGestureRecognizer *)ges{
    
    [self PlayOrPause:self.playOrPauseBtn];
    
    [self showControlView];
}

#pragma mark *** 单击
- (void)handleSingleTap:(UIGestureRecognizer *)ges{
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoDismissBottomView:) object:nil];
    
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
    [UIView animateWithDuration:0.5 animations:^{
        if (self.bottomView.alpha == 0.0) {
            [self showControlView];
        }else{
            [self hiddenControlView];
        }
    } completion:^(BOOL finish){
        
    }];
}


#pragma mark *** 关闭
- (void)colseTheVideo:(UIButton *)button{
    
}

#pragma mark *** 全屏
- (void)fullScreenAction:(UIButton *)button{
    button.selected = !button.selected;
    
}

#pragma mark *** 进度条
// 视频进度条的点击事件
- (void)actionTapGesture:(UIGestureRecognizer *)ges{
    CGPoint touchLocation = [ges locationInView:self.progressSlider];
    CGFloat value = (self.progressSlider.maximumValue - self.progressSlider.minimumValue) * (touchLocation.x/self.progressSlider.frame.size.width);
    [self.progressSlider setValue:value animated:YES];
    
    [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale)];
    if (self.player.rate != 1.f) {
        if ([self currentTime] == [self duration])
            [self setCurrentTime:0.f];
        self.playOrPauseBtn.selected = NO;
        [self.player play];
    }
}

// 进度条点击
- (void)updateProgress:(UISlider *)slider{
    self.isDragingSlider = NO;
    [self.player seekToTime:CMTimeMakeWithSeconds(slider.value, _currentItem.currentTime.timescale)];
}
// 进度条开始拖拽
- (void)stratDragSlide:(UISlider *)slider{
    self.isDragingSlider = YES;
}

#pragma mark *** 播放暂停
- (void)PlayOrPause:(UIButton *)button{
    if (self.state == JXPlayerStateStopped || self.state == JXPlayerStateFailed) {
        [self play];
    } else if(self.state == JXPlayerStatePlaying){
        [self pause];
    }else if(self.state == JXPlayerStateFinished){
        NSLog(@"ggggg");
        self.state = JXPlayerStatePlaying;
        [self.player play];
        self.playOrPauseBtn.selected = NO;
    }
    
    
}

#pragma mark *** autoDismissBottomView
- (void)autoDismissBottomView:(NSTimer *)timer{
    if (self.state == JXPlayerStatePlaying) {
        if (self.bottomView.alpha == 1.0) {
            [self hiddenControlView];//隐藏操作栏
        }
    }
}


#pragma mark - Private Method
/// 显示操作栏view
- (void)showControlView{
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
        
    } completion:^(BOOL finish){
        
    }];
}
/// 隐藏操作栏view
- (void)hiddenControlView{
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 0.0;
        self.topView.alpha = 0.0;
        
    } completion:^(BOOL finish){
        
    }];
}

- (NSString *)convertTime:(float)second{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    if (second/3600 >= 1) {
        [[self dateFormatter] setDateFormat:@"HH:mm:ss"];
    } else {
        [[self dateFormatter] setDateFormat:@"mm:ss"];
    }
    return [[self dateFormatter] stringFromDate:d];
}

- (void)setCurrentTime:(double)time{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.player seekToTime:CMTimeMakeWithSeconds(time, self.currentItem.currentTime.timescale)];
        
    });
}


- (void)creatJXPlayerAndReadyToPlay{
    //设置player的参数
    self.currentItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:self.URLString]];
    
    self.player = [AVPlayer playerWithPlayerItem:_currentItem];
    if ([self.player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    self.player.usesExternalPlaybackWhileExternalScreenIsActive=YES;
    //AVPlayerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.contentView.layer.bounds;
    //JXPlayer视频的默认填充模式，AVLayerVideoGravityResizeAspect
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.contentView.layer insertSublayer:_playerLayer atIndex:0];
    self.state = JXPlayerStateBuffering;
}

#pragma mark - setter
///获取视频长度
- (double)duration{
    AVPlayerItem *playerItem = self.player.currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([[playerItem asset] duration]);
    }
    else{
        return 0.f;
    }
}

#pragma mark - Public Method
/// 播放
- (void)play{
    
    if (self.isInitPlayer == NO) {
        self.isInitPlayer = YES;
        [self creatJXPlayerAndReadyToPlay];
        [self.player play];
        self.playOrPauseBtn.selected = NO;
    }else{
        if (self.state == JXPlayerStateStopped || self.state == JXPlayerStatePause) {
            self.state = JXPlayerStatePlaying;
            [self.player play];
            self.playOrPauseBtn.selected = NO;
        }else if(self.state == JXPlayerStateFinished){
            NSLog(@"fffff");
        }
    }
}

///暂停
-(void)pause{
    if (self.state == JXPlayerStatePlaying) {
        self.state = JXPlayerStateStopped;
    }
    [self.player pause];
    self.playOrPauseBtn.selected = YES;
}

///获取视频当前播放的时间
- (double)currentTime{
    if (self.player) {
        return CMTimeGetSeconds([self.player currentTime]);
    }else{
        return 0.0;
    }
}

//重置播放器
-(void )resetJXPlayer{

    self.currentItem = nil;
    self.seekTime = 0;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 关闭定时器
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    // 暂停
    [self.player pause];
    // 移除原来的layer
    [self.playerLayer removeFromSuperlayer];
    // 替换PlayerItem为nil
    [self.player replaceCurrentItemWithPlayerItem:nil];
    // 把player置为nil
    self.player = nil;
}

//获取当前的旋转状态
+ (CGAffineTransform)getCurrentDeviceOrientation{
    // 状态条的方向已经设置过,所以这个就是你想要旋转的方向
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    //根据要进行旋转的方向来计算旋转的角度
    if (orientation ==UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    }else if (orientation ==UIInterfaceOrientationLandscapeLeft){
        return CGAffineTransformMakeRotation(-M_PI_2);
    }else if(orientation ==UIInterfaceOrientationLandscapeRight){
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}

@end
