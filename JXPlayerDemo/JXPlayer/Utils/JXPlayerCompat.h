//
//  JXPlayerCompat.h
//  JXPlayerDemo
//
//  Created by yituiyun on 2017/11/7.
//  Copyright © 2017年 yituiyun. All rights reserved.
//

/**！
 我们可以像这样在定义宏的时候使用换行，但需要添加  操作符
 1.如果当前线程已经是主线程了，那么在调用dispatch_async(dispatch_get_main_queue(), block)有可能会出现crash
 2.如果当前线程是主线程，直接调用，如果不是，调用dispatch_async(dispatch_get_main_queue(), block)
 */

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#endif

