//
//  MDLagMonitor.m
//  CrashExceptionHandler
//
//  Created by weiguang on 2020/3/3.
//  Copyright © 2020 weiguang. All rights reserved.
//

#import "MDLagMonitor.h"
#import "MDCPUMonitor.h"
#import "SMCallStack.h"
#import <CrashReporter/CrashReporter.h>

@interface MDLagMonitor()
{
    int timeoutCount;
    CFRunLoopObserverRef runLoopObserver;
    @public
    dispatch_semaphore_t dispatchSemaphore;
    CFRunLoopActivity runLoopActivity;
}
@property (nonatomic, strong) NSTimer *cpuMonitorTimer;
@end

@implementation MDLagMonitor

+ (instancetype)shareInstance {
    
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)beginMonitor {
    // 检测CPU消耗
    self.cpuMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(updateCPUInfo) userInfo:nil repeats:YES];
    //监测卡顿
    if (runLoopObserver) {
        return;
    }
    
    dispatchSemaphore = dispatch_semaphore_create(0);//Dispatch Semaphore保证同步
    //创建一个观察者
    //第一个参数用于分配observer对象的内存
    //第二个参数用以设置observer所要关注的事件
    //第三个参数用于标识该observer是在第一次进入run loop时执行还是每次进入run loop处理时均执行
    //第四个参数用于设置该observer的优先级
    //第五个参数用于设置该observer的回调函数
    //第六个参数用于设置该observer的运行环境
    CFRunLoopObserverContext context = {0,(__bridge void *)self,NULL,NULL};
    runLoopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                              kCFRunLoopAllActivities,
                                              YES,
                                              0,
                                              &runLoopObserverCallBack,
                                              &context);
    //将观察者添加到主线程runloop的common模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    
    // 创建子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
       //子线程开启一个持续的loop用来进行监控
        while (YES) {
            // 有信号的话 就查询当前runloop的状态
            // 假定连续5次超时50ms认为卡顿(当然也包含了单次超时250ms)
            // 因为下面 runloop 状态改变回调方法runLoopObserverCallBack中会将信号量递增 1,所以每次 runloop 状态改变后,下面的语句都会执行一次
            // dispatch_semaphore_wait:Returns zero on success, or non-zero if the timeout occurred.
            // 这个地方的时间有待验证
            long semaphoreWait = dispatch_semaphore_wait(dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC));
            if (semaphoreWait != 0) {
                if (!self->runLoopObserver) {
                    self->timeoutCount = 0;
                    self->dispatchSemaphore = 0;
                    self->runLoopActivity = 0;
                    return;
                }
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够检测到是否卡顿
                if (self->runLoopActivity == kCFRunLoopBeforeSources || self->runLoopActivity == kCFRunLoopAfterWaiting) {
                   // 出现三次出结果
//                   if (++timeoutCount < 3) {
//                       continue;
//                   }
                    NSLog(@"monitor trigger");
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        // 下面2种方法收集Crash信息也可用于实时获取各线程的调用堆栈。
                          
                          // 1、自己获取
                        //  NSString *report = [SMCallStack callStackWithType:SMCallStackTypeAll];
                          
                          // 2、通过三方库获取
                          PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
                          
                          PLCrashReporter *crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];
                          
                          NSData *data = [crashReporter generateLiveReport];
                          PLCrashReport *reporter = [[PLCrashReport alloc] initWithData:data error:NULL];
                          NSString *report = [PLCrashReportTextFormatter stringValueForCrashReport:reporter withTextFormat:PLCrashReportTextFormatiOS];
                          
                          NSLog(@"---------卡顿信息\n%@\n--------------",report);
                    });
                }//end activity
                
            }// end semaphore wait
            self->timeoutCount = 0;
        }// end while
    });
    
}

- (void)endMonitor {
    [self.cpuMonitorTimer invalidate];
    if (!runLoopObserver) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    CFRelease(runLoopObserver);
    runLoopObserver = NULL;
}



#pragma mark - Private
- (void)updateCPUInfo {
    [MDCPUMonitor updateCPU];
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    MDLagMonitor *lagMonitor = (__bridge MDLagMonitor*)info;
    lagMonitor->runLoopActivity = activity;
    
    dispatch_semaphore_t semaphore = lagMonitor->dispatchSemaphore;
    dispatch_semaphore_signal(semaphore);
}

@end
