#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface YZConfigManager : NSObject

+ (instancetype)shared;

/// 从默认配置加载
+ (void)loadConfiguration;

/// 获取配置值
- (id)valueForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (CGFloat)floatForKey:(NSString *)key;

/// 设置配置值
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

/// 重置为默认配置
- (void)resetToDefaults;

/// 导出配置（不含敏感信息）
- (NSDictionary *)exportConfig;

@end
