#import "YZCrashGuard.h"
#import "YZRuntimeLogger.h"
#import <UIKit/UIKit.h>

static NSMutableDictionary<NSString *, NSMutableArray<NSDate *> *> *sCrashTimestamps = nil;
static NSMutableSet<NSString *> *sDisabledFeatures = nil;
static const NSTimeInterval kCrashWindowSeconds = 0.1;   // 100ms 窗口
static const NSInteger kMaxCrashesPerWindow = 3;          // 窗口中最多崩溃次数

// 前一个异常处理器
static NSUncaughtExceptionHandler *sPreviousExceptionHandler = NULL;

@implementation YZCrashGuard

+ (void)registerAll {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sCrashTimestamps = [NSMutableDictionary dictionary];
        sDisabledFeatures = [NSMutableSet set];
        [self registerUncaughtExceptionHandler];
        [self registerSignalHandlers];
        NSLog(@"[小杳知] 崩溃防护已激活");
        [YZRuntimeLogger logEvent:@"crash_guard.registered"];
    });
}

#pragma mark - Exception Handler

+ (void)registerUncaughtExceptionHandler {
    sPreviousExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&YZUncaughtExceptionHandler);
}

static void YZUncaughtExceptionHandler(NSException *exception) {
    NSString *context = [NSString stringWithFormat:@"未捕获异常: %@ | %@ | %@",
                         exception.name,
                         exception.reason ?: @"无原因",
                         [exception.callStackSymbols componentsJoinedByString:@" | "]];

    NSLog(@"[小杳知] 🛑 %@", context);

    // 写入沙盒日志
    [YZCrashGuard writeCrashLog:context];

    // 调用前一个处理器
    if (sPreviousExceptionHandler) {
        sPreviousExceptionHandler(exception);
    }
}

#pragma mark - Signal Handler

+ (void)registerSignalHandlers {
    signal(SIGABRT, YZSignalHandler);
    signal(SIGSEGV, YZSignalHandler);
    signal(SIGBUS, YZSignalHandler);
    signal(SIGTRAP, YZSignalHandler);
    signal(SIGILL, YZSignalHandler);
}

static void YZSignalHandler(int signal) {
    NSString *signalName;
    switch (signal) {
        case SIGABRT: signalName = @"SIGABRT"; break;
        case SIGSEGV: signalName = @"SIGSEGV"; break;
        case SIGBUS:   signalName = @"SIGBUS"; break;
        case SIGTRAP:  signalName = @"SIGTRAP"; break;
        case SIGILL:   signalName = @"SIGILL"; break;
        default:       signalName = [NSString stringWithFormat:@"信号(%d)", signal]; break;
    }

    NSString *context = [NSString stringWithFormat:@"信号崩溃: %@", signalName];
    NSLog(@"[小杳知] 🛑 %@", context);
    [YZCrashGuard writeCrashLog:context];

    // 不调用 exit()，让系统继续处理
}

#pragma mark - Crash Logging

+ (void)writeCrashLog:(NSString *)message {
    @try {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *logPath = [docPath stringByAppendingPathComponent:@"xiaoyaozhi_crash.log"];

        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                             dateStyle:NSDateFormatterShortStyle
                                                             timeStyle:NSDateFormatterMediumStyle];
        NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

        if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            [handle seekToEndOfFile];
            [handle writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        } else {
            [entry writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    } @catch (__unused NSException *e) {
        // 日志写入失败不处理
    }
}

+ (void)logCrashContext:(NSString *)location {
    if (!location) return;
    NSLog(@"[小杳知] ⚠️ 异常恢复: %@", location);
    [YZRuntimeLogger logEvent:@"crash_guard.recovered" info:@{@"location": location}];
}

#pragma mark - Recursive Crash Detection

+ (BOOL)checkAndLogCrashForLocation:(NSString *)location {
    if (!location) return YES; // 允许通过
    if ([sDisabledFeatures containsObject:location]) return NO; // 功能已禁用

    @synchronized (sCrashTimestamps) {
        NSMutableArray<NSDate *> *timestamps = sCrashTimestamps[location];
        if (!timestamps) {
            timestamps = [NSMutableArray array];
            sCrashTimestamps[location] = timestamps;
        }

        NSDate *now = [NSDate date];

        // 清理过期记录
        [timestamps filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDate *date, __unused NSDictionary *bindings) {
            return [now timeIntervalSinceDate:date] < kCrashWindowSeconds;
        }]];

        [timestamps addObject:now];

        if (timestamps.count >= kMaxCrashesPerWindow) {
            // 禁用该功能
            [sDisabledFeatures addObject:location];
            NSLog(@"[小杳知] 🔒 功能已禁用（递归崩溃防护: %@ | %lu次/%0.0fms）",
                  location, (unsigned long)timestamps.count, kCrashWindowSeconds * 1000);
            [YZRuntimeLogger logEvent:@"crash_guard.disable_feature" info:@{
                @"location": location,
                @"count": @(timestamps.count)
            }];
            return NO;
        }
    }

    return YES;
}

+ (void)resetCrashCounters {
    @synchronized (sCrashTimestamps) {
        [sCrashTimestamps removeAllObjects];
        [sDisabledFeatures removeAllObjects];
        NSLog(@"[小杳知] 崩溃计数器已重置");
        [YZRuntimeLogger logEvent:@"crash_guard.reset"];
    }
}

@end
