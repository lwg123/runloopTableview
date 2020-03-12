//
//  ViewController.m
//  runloop优化tableview
//
//  Created by weiguang on 2017/10/30.
//  Copyright © 2017年 weiguang. All rights reserved.
//
/**
 所有的耗时操作都可以化整为零！！
 
 加载高清大图会卡，为什么？
 因为runloop负责UI渲染
 一次runloop循环需要渲染所有的图片
 
 优化：
 手动的让一次runloop循环只渲染一张图片
 
 监听runloop循环，每次循环，加载一张！！
 */

#import "ViewController.h"
#import "FluencyMonitor.h"

typedef void(^RunloopBlock)(void);

static NSString *cellID = @"IDENTIFIER";
static CGFloat CELL_HEIGHT = 135.f;

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) UITableView *exampleTableView;
@property (nonatomic, strong) NSMutableArray *tasks;
@property (nonatomic, assign) NSString *str;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _tasks = [NSMutableArray array];
    
    self.str = @"abcdefg";
    NSLog(@"打印%@",self.str);
    
    // 添加timer到当前runloop中，保证runloop不退出
   // [NSTimer scheduledTimerWithTimeInterval:0.0001 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
    self.exampleTableView = [UITableView new];
    self.exampleTableView.dataSource = self;
    self.exampleTableView.delegate = self;
    [self.view addSubview:self.exampleTableView];
    
    [self.exampleTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:cellID];
    
    [self addRunloopObserver];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopMonitor)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(startMonitor)];
}

- (void)stopMonitor
{
    [[FluencyMonitor shareMonitor] stop];
}


- (void)startMonitor
{
    [[FluencyMonitor shareMonitor] start];
}



- (void)timerMethod{
    // 啥都不做，保持线程
}


// 在此时添加frame
- (void)viewWillAppear:(BOOL)animated{
    self.exampleTableView.frame = self.view.bounds;
}

#pragma mark - <UITableViewDataSource>
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 300;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return CELL_HEIGHT;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // 干掉contentView上的子控件，节约内存
    for (NSInteger i = 1; i <= 5; i++) {
        [[cell.contentView viewWithTag:i] removeFromSuperview];
    }
    
    // 添加文字
    [self addText:cell indexPath:indexPath];
   
    // 添加图片 -- 这种添加图片方式会导致页面卡顿，不流畅，通过runloop对齐进行优化
    [self addImage1Withcell:cell];
    [self addImage2Withcell:cell];
    [self addImage3Withcell:cell];
   
    //runloop 优化方式，把代码放进数组里，然后在runloop中执行
//    [self addtask:^{
//        [self addImage1Withcell:cell];
//    }];
//    [self addtask:^{
//        [self addImage2Withcell:cell];
//    }];
//    [self addtask:^{
//        [self addImage3Withcell:cell];
//    }];
//
    
    return cell;
}


#pragma mark - <关于Runloop的>
// 添加任务的方法
- (void)addtask:(RunloopBlock)block{
    [self.tasks addObject:block];
    // 为了保证屏幕以外的图片不用渲染,超出最大显示数量的图片时
    if (self.tasks.count > 18) {
        [self.tasks removeObjectAtIndex:0];
    }
    
}

// 添加观察者
- (void)addRunloopObserver{
    //拿到当前Runloop
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    
    //定义观察者
    static CFRunLoopObserverRef runloopObserver;
    
    // 创建上下文
    CFRunLoopObserverContext context = {
        0,
        (__bridge void *)self, //在会调用中获取到self
        &CFRetain,
        &CFRelease,
        NULL
    };
    
    runloopObserver = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting, YES, 0, &callBack, &context);
    
    // 添加到当前的Runloop中,使用kCFRunLoopCommonModes模式可以在拖动时渲染
    CFRunLoopAddObserver(runloop, runloopObserver, kCFRunLoopCommonModes);
    
    CFRelease(runloopObserver);
    
}

static void callBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    // 在这个函数里self不能用，需要用context转换一下，info就是控制器，从context传过来的
    ViewController *vc = (__bridge ViewController *)info;
   // NSLog(@"来了%zd",vc.tasks.count);
    if (vc.tasks.count) {
        // 从数组中获取任务
        RunloopBlock block = vc.tasks.firstObject;
        // 执行任务
        block();
        // 干掉数组中完成的任务
        [vc.tasks removeObjectAtIndex:0];
    }
   
}


- (void)addImage1Withcell:(UITableViewCell *)cell{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(105, 20, 85, 85)];
    imageView.tag = 2;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"1.JPG" ofType:nil];
   // NSString *path = [[NSBundle mainBundle] pathForResource:@"spaceship" ofType:@"jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = image;
    [UIView transitionWithView:cell.contentView duration:0.3 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [cell.contentView addSubview:imageView];
    } completion:^(BOOL finished) {
    }];
}

- (void)addImage2Withcell:(UITableViewCell *)cell{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(200, 20, 85, 85)];
    imageView.tag = 3;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"spaceship" ofType:@"jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = image;
    [UIView transitionWithView:cell.contentView duration:0.3 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [cell.contentView addSubview:imageView];
    } completion:^(BOOL finished) {
    }];
}

- (void)addImage3Withcell:(UITableViewCell *)cell{
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 20, 85, 85)];
    imageView.tag = 5;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"spaceship" ofType:@"jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = image;
    [UIView transitionWithView:cell.contentView duration:0.3 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve animations:^{
        
        [cell.contentView addSubview:imageView];
    } completion:^(BOOL finished) {
    }];
}

// 添加文字
- (void)addText:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 300, 25)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor redColor];
    label.text = [NSString stringWithFormat:@"%zd - Drawing index is top priority", indexPath.row];
    label.font = [UIFont boldSystemFontOfSize:13];
    label.tag = 1;
    [cell.contentView addSubview:label];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(5, 99, 300, 35)];
    label2.lineBreakMode = NSLineBreakByWordWrapping;
    label2.numberOfLines = 0;
    label2.backgroundColor = [UIColor clearColor];
    label2.textColor = [UIColor colorWithRed:0 green:100.f/255.f blue:0 alpha:1];
    label2.text = [NSString stringWithFormat:@" %zd - Drawing large image is low priority. Should be distributed into different run loop passes.",indexPath.row];
    label2.font = [UIFont boldSystemFontOfSize:13];
    label2.tag = 4;
    [cell.contentView addSubview:label2];
}



@end
