#import "YZWCRuntime.h"
#import "YZCrashGuard.h"

@implementation YZWCRuntime

#pragma mark - Safe Class Access

+ (Class)safeGetClass:(NSString *)className {
    if (className.length == 0) return nil;

    @try {
        Class cls = NSClassFromString(className);
        if (!cls) {
            NSLog(@"[小杳知] 微信类未找到: %@", className);
        }
        return cls;
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:[NSString stringWithFormat:@"safeGetClass:%@", className]];
        return nil;
    }
}

#pragma mark - Safe Method Calls

+ (id)safePerformSelector:(SEL)selector onTarget:(id)target {
    if (!target || !selector) return nil;

    @try {
        if (![target respondsToSelector:selector]) return nil;
        return ((id (*)(id, SEL))objc_msgSend)(target, selector);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:[NSString stringWithFormat:@"safePerformSelector:%@", NSStringFromSelector(selector)]];
        return nil;
    }
}

+ (id)safePerformSelector:(SEL)selector onTarget:(id)target withObject:(id)obj1 {
    if (!target || !selector) return nil;

    @try {
        if (![target respondsToSelector:selector]) return nil;
        return ((id (*)(id, SEL, id))objc_msgSend)(target, selector, obj1);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:[NSString stringWithFormat:@"safePerformSelector:%@ (1 arg)", NSStringFromSelector(selector)]];
        return nil;
    }
}

+ (id)safePerformSelector:(SEL)selector onTarget:(id)target withObject:(id)obj1 withObject:(id)obj2 {
    if (!target || !selector) return nil;

    @try {
        if (![target respondsToSelector:selector]) return nil;
        return ((id (*)(id, SEL, id, id))objc_msgSend)(target, selector, obj1, obj2);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:[NSString stringWithFormat:@"safePerformSelector:%@ (2 args)", NSStringFromSelector(selector)]];
        return nil;
    }
}

+ (BOOL)target:(id)target respondsTo:(SEL)selector {
    if (!target || !selector) return NO;
    return [target respondsToSelector:selector];
}

#pragma mark - Service Center

+ (id)getServiceCenter {
    Class mmServiceCenter = [self safeGetClass:@"MMServiceCenter"];
    if (!mmServiceCenter) return nil;

    id center = [self safePerformSelector:@selector(defaultCenter) onTarget:mmServiceCenter];
    return center;
}

+ (id)getService:(NSString *)serviceClassName {
    Class serviceClass = [self safeGetClass:serviceClassName];
    if (!serviceClass) return nil;

    id center = [self getServiceCenter];
    id service = [self safePerformSelector:@selector(getService:) onTarget:center withObject:serviceClass];
    if (service) return service;

    Class contextClass = [self safeGetClass:@"MMContext"];
    SEL activeUserContextSelector = NSSelectorFromString(@"activeUserContext");
    if (![contextClass respondsToSelector:activeUserContextSelector]) return nil;

    id context = [self safePerformSelector:activeUserContextSelector onTarget:contextClass];
    id userCenter = [self safePerformSelector:NSSelectorFromString(@"serviceCenter") onTarget:context];
    return [self safePerformSelector:@selector(getService:) onTarget:userCenter withObject:serviceClass];
}

#pragma mark - Bundle Check

+ (BOOL)isWeChatBundle {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (bundleID.length == 0) return NO;

    return [bundleID isEqualToString:@"com.tencent.xin"] ||
           [bundleID isEqualToString:@"com.tencent.qy.xin"] ||
           [bundleID isEqualToString:@"com.tencent.wx"];
}

@end
