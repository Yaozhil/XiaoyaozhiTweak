#import <Foundation/Foundation.h>

// 异步执行器 - 管理后台任务调度
@interface YZAsyncExecutor : NSObject

/// 在主线程异步执行
+ (void)executeOnMainThread:(void(^)(void))block;

/// 在后台队列执行
+ (void)executeOnBackground:(void(^)(void))block;

/// 在后台队列执行，完成后回到主线程
+ (void)executeOnBackground:(void(^)(void))backgroundBlock
                 completion:(void(^)(void))completionBlock;

/// 延迟在主线程执行
+ (void)executeAfterDelay:(NSTimeInterval)seconds block:(void(^)(void))block;

/// 在自定义 QoS 队列执行
+ (void)executeWithQoS:(dispatch_qos_class_t)qos block:(void(^)(void))block;

@end
