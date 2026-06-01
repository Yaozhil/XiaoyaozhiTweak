#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// 微信运行时桥接 - 安全封装 objc_msgSend 调用
@interface YZWCRuntime : NSObject

/// 获取微信内部类
+ (Class)safeGetClass:(NSString *)className;

/// 安全调用对象方法（带返回值检查）
+ (id)safePerformSelector:(SEL)selector onTarget:(id)target;

/// 安全调用带参数的对象方法
+ (id)safePerformSelector:(SEL)selector onTarget:(id)target withObject:(id)obj1;

/// 安全调用带2个参数的对象方法
+ (id)safePerformSelector:(SEL)selector onTarget:(id)target withObject:(id)obj1 withObject:(id)obj2;

/// 检查 selector 是否存在
+ (BOOL)target:(id)target respondsTo:(SEL)selector;

/// 获取微信 MMServiceCenter 实例
+ (id)getServiceCenter;

/// 通过 MMServiceCenter 获取服务实例
+ (id)getService:(NSString *)serviceClassName;

/// 判断是否为微信目标包
+ (BOOL)isWeChatBundle;

@end
