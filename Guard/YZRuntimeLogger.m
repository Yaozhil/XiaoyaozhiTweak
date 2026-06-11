#import "YZRuntimeLogger.h"

static NSMutableArray<NSString *> *sYZRuntimeLogBuffer = nil;
static dispatch_queue_t sYZRuntimeLogQueue = nil;
static NSString *sYZRuntimeLogPath = nil;
static const NSUInteger kYZRuntimeLogMaxEntries = 220;
static const unsigned long long kYZRuntimeLogMaxFileSize = 96 * 1024;

@implementation YZRuntimeLogger

+ (void)initialize {
    if (self != YZRuntimeLogger.class) return;
    sYZRuntimeLogBuffer = [NSMutableArray array];
    sYZRuntimeLogQueue = dispatch_queue_create("com.rouneed.xiaoyaozhi.runtime-log", DISPATCH_QUEUE_SERIAL);
}

+ (NSString *)logPath {
    if (sYZRuntimeLogPath) return sYZRuntimeLogPath;

    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (docPath.length == 0) docPath = NSTemporaryDirectory();
    sYZRuntimeLogPath = [docPath stringByAppendingPathComponent:@"xiaoyaozhi_runtime.log"];
    return sYZRuntimeLogPath;
}

+ (NSString *)timestampString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    return [formatter stringFromDate:[NSDate date]];
}

+ (NSString *)stringFromInfo:(NSDictionary *)info {
    if (info.count == 0) return @"";

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
    if (jsonData.length > 0) {
        NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if (json.length > 0) return [NSString stringWithFormat:@" %@", json];
    }
    return [NSString stringWithFormat:@" %@", info];
}

+ (void)writeLineToFile:(NSString *)line {
    @autoreleasepool {
        NSString *path = [self logPath];
        NSString *entry = [line stringByAppendingString:@"\n"];
        NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];

        if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
            [data writeToFile:path atomically:YES];
        } else {
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        }

        NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        unsigned long long size = [attr[NSFileSize] unsignedLongLongValue];
        if (size <= kYZRuntimeLogMaxFileSize) return;

        NSData *fullData = [NSData dataWithContentsOfFile:path];
        if (fullData.length <= kYZRuntimeLogMaxFileSize) return;
        NSData *tail = [fullData subdataWithRange:NSMakeRange(fullData.length - kYZRuntimeLogMaxFileSize, kYZRuntimeLogMaxFileSize)];
        [tail writeToFile:path atomically:YES];
    }
}

+ (void)rememberLine:(NSString *)line {
    @synchronized (sYZRuntimeLogBuffer) {
        [sYZRuntimeLogBuffer addObject:line];
        while (sYZRuntimeLogBuffer.count > kYZRuntimeLogMaxEntries) {
            [sYZRuntimeLogBuffer removeObjectAtIndex:0];
        }
    }
}

+ (void)appendLine:(NSString *)line sync:(BOOL)sync {
    if (line.length == 0) return;

    [self rememberLine:line];

    if (sync) {
        [self writeLineToFile:line];
        return;
    }

    dispatch_async(sYZRuntimeLogQueue, ^{
        @autoreleasepool {
            [self writeLineToFile:line];
        }
    });
}

+ (void)logEvent:(NSString *)event {
    [self logEvent:event info:nil];
}

+ (void)logEvent:(NSString *)event info:(NSDictionary *)info {
    if (event.length == 0) return;

    NSMutableDictionary *safeInfo = [NSMutableDictionary dictionary];
    [info enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (!key || !obj || obj == (id)kCFNull) return;
        if ([NSJSONSerialization isValidJSONObject:@{key: obj}]) {
            safeInfo[key] = obj;
        } else {
            safeInfo[key] = [obj description] ?: @"";
        }
    }];

    NSString *line = [NSString stringWithFormat:@"[%@] %@%@",
                      [self timestampString],
                      event,
                      [self stringFromInfo:safeInfo]];
    NSLog(@"[小杳知][运行日志] %@", line);
    [self appendLine:line sync:NO];
}

+ (void)logEventSync:(NSString *)event info:(NSDictionary *)info {
    if (event.length == 0) return;

    NSMutableDictionary *safeInfo = [NSMutableDictionary dictionary];
    [info enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (!key || !obj || obj == (id)kCFNull) return;
        if ([NSJSONSerialization isValidJSONObject:@{key: obj}]) {
            safeInfo[key] = obj;
        } else {
            safeInfo[key] = [obj description] ?: @"";
        }
    }];

    NSString *line = [NSString stringWithFormat:@"[%@] %@%@",
                      [self timestampString],
                      event,
                      [self stringFromInfo:safeInfo]];
    NSLog(@"[小杳知][运行日志] %@", line);
    [self appendLine:line sync:YES];
}

+ (NSString *)recentLogText {
    NSMutableArray<NSString *> *merged = [NSMutableArray array];

    NSString *path = [self logPath];
    NSString *fileText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (fileText.length > 0) {
        NSArray<NSString *> *fileLines = [fileText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
        for (NSString *line in fileLines) {
            if (line.length > 0) [merged addObject:line];
        }
    }

    NSMutableArray<NSString *> *lines = nil;
    @synchronized (sYZRuntimeLogBuffer) {
        lines = [sYZRuntimeLogBuffer mutableCopy];
    }
    for (NSString *line in lines) {
        if (line.length == 0) continue;
        if (merged.count > 0 && [merged.lastObject isEqualToString:line]) continue;
        [merged addObject:line];
    }

    while (merged.count > kYZRuntimeLogMaxEntries) {
        [merged removeObjectAtIndex:0];
    }
    return [merged componentsJoinedByString:@"\n"] ?: @"";
}

+ (void)clearLogs {
    @synchronized (sYZRuntimeLogBuffer) {
        [sYZRuntimeLogBuffer removeAllObjects];
    }
    dispatch_async(sYZRuntimeLogQueue, ^{
        [NSFileManager.defaultManager removeItemAtPath:[self logPath] error:nil];
    });
}

@end
