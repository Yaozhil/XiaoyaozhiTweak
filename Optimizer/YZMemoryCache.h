#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 内存缓存池 - LRU 淘汰 + 内存警告响应
@interface YZMemoryCache : NSObject

+ (instancetype)shared;

/// 存储对象
- (void)setObject:(id)obj forKey:(NSString *)key cost:(NSUInteger)cost;

/// 读取对象
- (id)objectForKey:(NSString *)key;

/// 移除对象
- (void)removeObjectForKey:(NSString *)key;

/// 移除所有缓存
- (void)removeAllObjects;

/// 预热常用资源
- (void)prewarmCommonAssets;

/// 响应内存警告 - 清除一半缓存
- (void)purgeOnMemoryWarning;

/// 最大缓存大小 (MB)，默认 8
@property (nonatomic) NSUInteger maxCacheSizeMB;

/// 最大缓存条目数，默认 50
@property (nonatomic) NSUInteger maxEntryCount;

/// 当前缓存条目数
@property (nonatomic, readonly) NSUInteger currentEntryCount;

@end
