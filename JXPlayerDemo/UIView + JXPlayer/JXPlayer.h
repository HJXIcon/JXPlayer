//
//  JXPlayer.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/8.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

@import MediaPlayer;
@import AVFoundation;
@import UIKit;

FOUNDATION_EXPORT NSString *const kTBPlayerStateChangedNotification;
FOUNDATION_EXPORT NSString *const kTBPlayerProgressChangedNotification;
FOUNDATION_EXPORT NSString *const kTBPlayerLoadProgressChangedNotification;

//播放器的几种状态
typedef NS_ENUM(NSInteger, JXPlayerState) {
    JXPlayerStateFailed,     // 播放失败
    JXPlayerStateBuffering,  // 缓冲中
    JXPlayerStatePlaying,    // 播放中
    JXPlayerStateStopped,    // 暂停播放
    JXPlayerStateFinished,   // 暂停播放
    JXPlayerStatePause       // 暂停播放
};

// 枚举值，包含播放器左上角的关闭按钮的类型
typedef NS_ENUM(NSInteger, JXCloseBtnStyle){
    JXCloseBtnStylePop,   // pop箭头<-
    JXCloseBtnStyleClose  // 关闭（X）
};

//手势操作的类型
typedef NS_ENUM(NSUInteger,JXControlType) {
    JXControlTypeProgress, // 视频进度调节操作
    JXControlTypeVoice,    // 声音调节操作
    JXControlTypeLight,    // 屏幕亮度调节操作
    JXControlTypeNone      // 无任何操作
} ;


@class JXPlayer;
@protocol JXPlayerDelegate <NSObject>

@end


@interface JXPlayer : UIView

/**
 *  播放器player
 */
@property (nonatomic,retain ) AVPlayer *player;
/**
 *playerLayer,可以修改frame
 */
@property (nonatomic,retain ) AVPlayerLayer *playerLayer;

/** 播放器的代理 */
@property (nonatomic, weak)id <JXPlayerDelegate> delegate;
/**
 *  底部操作工具栏
 */
@property (nonatomic,retain ) UIImageView *bottomView;
/**
 *  顶部操作工具栏
 */
@property (nonatomic,retain ) UIImageView *topView;
/**
 *  是否使用手势控制音量
 */
@property (nonatomic,assign) BOOL enableVolumeGesture;
/**
 *  是否使用手势控制音量
 */
@property (nonatomic,assign) BOOL enableFastForwardGesture;
/**
 *  显示播放视频的title
 */
@property (nonatomic,strong) UILabel *titleLabel;
/**
 ＊  播放器状态
 */
@property (nonatomic, assign) JXPlayerState state;
/**
 ＊  播放器左上角按钮的类型
 */
@property (nonatomic, assign) JXCloseBtnStyle closeBtnStyle;
/**
 *  定时器
 */
@property (nonatomic, retain) NSTimer *autoDismissTimer;
/**
 *  BOOL值判断当前的状态
 */
@property (nonatomic,assign ) BOOL isFullscreen;
/**
 *  控制全屏的按钮
 */
@property (nonatomic,retain ) UIButton *fullScreenBtn;
/**
 *  播放暂停按钮
 */
@property (nonatomic,retain ) UIButton *playOrPauseBtn;
/**
 *  左上角关闭按钮
 */
@property (nonatomic,retain ) UIButton *closeBtn;
/**
 *  显示加载失败的UILabel
 */

@property (nonatomic,strong) UILabel *loadFailedLabel;

/**
 *  /给显示亮度的view添加毛玻璃效果
 */
@property (nonatomic, strong) UIVisualEffectView *effectView;
/**
 *  Player内部一个UIView，所有的控件统一管理在此view中
 */
@property (nonatomic,strong) UIView *contentView;
/**
 *  当前播放的item
 */
@property (nonatomic, retain) AVPlayerItem *currentItem;
/**
 *  菊花（加载框）
 */
@property (nonatomic,strong) UIActivityIndicatorView *loadingView;

/**
 *  设置播放视频的USRLString，可以是本地的路径也可以是http的网络路径
 */
@property (nonatomic,copy) NSString *URLString;

//这个用来显示滑动屏幕时的时间
//@property (nonatomic,strong) FastForwardView * FF_View;

/**
 *  跳到time处播放
 *  seekTime这个时刻，这个时间点
 */
@property (nonatomic, assign) double seekTime;

/** 播放前占位图片，不设置就显示默认占位图（需要在设置视频URL之前设置） */
@property (nonatomic, copy  ) UIImage *placeholderImage ;


///---------------------------------------------------


/**
 *  播放
 */
- (void)play;

/**
 * 暂停
 */
- (void)pause;

/**
 *  获取正在播放的时间点
 *
 *  @return double的一个时间点
 */
- (double)currentTime;

/**
 * 重置播放器
 */
- (void )resetJXPlayer;

//获取当前的旋转状态
+ (CGAffineTransform)getCurrentDeviceOrientation;


@end
