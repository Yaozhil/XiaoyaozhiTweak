#import <Foundation/Foundation.h>
#import <signal.h>

// 崩溃防护 - 异常捕获 + 信号处理 + 递归崩溃检测
@interface YZCrashGuard : NSObject

/// 注册所有崩溃防护
+ (void)registerAll;

/// 注册未捕获 Objective-C 异常处理器
+ (void)registerUncaughtExceptionHandler;

/// 注册信号处理器
+ (void)registerSignalHandlers;

/// 递归崩溃检测：同一个位置 100ms 内崩溃 >= 3 次则禁用相关功能
+ (BOOL)checkAndLogCrashForLocation:(NSString *)location;

/// 记录崩溃上下文
+ (void)logCrashContext:(NSString *)location;

/// 重置崩溃计数器（用于测试或恢复）
+ (void)resetCrashCounters;

@end
