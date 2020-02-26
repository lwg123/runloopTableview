//
//  FluencyMonitor.h
//  runloop优化tableview
//
//  Created by weiguang on 2020/2/25.
//  Copyright © 2020 weiguang. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface FluencyMonitor : NSObject

+ (instancetype)shareMonitor;

/**
 开始监控

 @param interval 定时器间隔时间
 @param fault 卡顿的阙值
 */
- (void)startWithInterval:(NSTimeInterval)interval fault:(NSTimeInterval)fault;


/**
 开始监控
 */
- (void)start;

// 停止监控
- (void)stop;

@end

NS_ASSUME_NONNULL_END
