#import <Foundation/Foundation.h>

// 运行日志 - 本地滚动记录，方便真机复现后复制反馈
@interface YZRuntimeLogger : NSObject

+ (void)logEvent:(NSString *)event;
+ (void)logEvent:(NSString *)event info:(NSDictionary *)info;
+ (NSString *)recentLogText;
+ (void)clearLogs;

@end
