//
//  MDLagMonitor.h
//  CrashExceptionHandler
//
//  Created by weiguang on 2020/3/3.
//  Copyright © 2020 weiguang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MDLagMonitor : NSObject

+ (instancetype)shareInstance;

- (void)beginMonitor; //开始监视卡顿
- (void)endMonitor;   //停止监视卡顿

@end

NS_ASSUME_NONNULL_END
