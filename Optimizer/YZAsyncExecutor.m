#import "YZAsyncExecutor.h"

@implementation YZAsyncExecutor

+ (void)executeOnMainThread:(void(^)(void))block {
    if (!block) return;

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

+ (void)executeOnBackground:(void(^)(void))block {
    if (!block) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

+ (void)executeOnBackground:(void(^)(void))backgroundBlock
                 completion:(void(^)(void))completionBlock {
    if (!backgroundBlock) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            backgroundBlock();
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), completionBlock);
        }
    });
}

+ (void)executeAfterDelay:(NSTimeInterval)seconds block:(void(^)(void))block {
    if (!block) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), block);
}

+ (void)executeWithQoS:(dispatch_qos_class_t)qos block:(void(^)(void))block {
    if (!block) return;

    dispatch_queue_t queue = dispatch_get_global_queue(qos, 0);
    dispatch_async(queue, block);
}

@end
