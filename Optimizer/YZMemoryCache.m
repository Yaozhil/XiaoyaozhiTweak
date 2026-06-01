#import "YZMemoryCache.h"
#import "YZConfigManager.h"

@interface YZCacheEntry : NSObject
@property (nonatomic, strong) id object;
@property (nonatomic, assign) NSUInteger cost;
@property (nonatomic, strong) NSDate *lastAccess;
@end

@implementation YZCacheEntry
@end

@interface YZMemoryCache () <NSCacheDelegate>
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, readwrite) NSUInteger currentEntryCount;
@property (nonatomic, strong) NSMutableSet<NSString *> *trackedKeys; // 手动追踪条目
@end

@implementation YZMemoryCache

+ (instancetype)shared {
    static YZMemoryCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YZMemoryCache alloc] init];
        [instance setup];
    });
    return instance;
}

- (void)setup {
    self.cache = [[NSCache alloc] init];
    self.cache.name = @"com.rouneed.xiaoyaozhi.cache";
    self.cache.delegate = self;
    self.trackedKeys = [NSMutableSet set];

    YZConfigManager *config = [YZConfigManager shared];
    self.maxCacheSizeMB = [config integerForKey:@"max_cache_size_mb"];
    self.maxEntryCount = [config integerForKey:@"max_cache_entries"];

    if (self.maxCacheSizeMB == 0) self.maxCacheSizeMB = 8;
    if (self.maxEntryCount == 0) self.maxEntryCount = 50;

    self.cache.totalCostLimit = self.maxCacheSizeMB * 1024 * 1024;
    self.cache.countLimit = self.maxEntryCount;

    // 监听内存警告
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)setObject:(id)obj forKey:(NSString *)key cost:(NSUInteger)cost {
    if (!obj || !key) return;
    [self.cache setObject:obj forKey:key cost:cost];
    @synchronized (self.trackedKeys) { [self.trackedKeys addObject:key]; }
    self.currentEntryCount = self.trackedKeys.count;
}

- (id)objectForKey:(NSString *)key {
    if (!key) return nil;
    return [self.cache objectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
    if (!key) return;
    [self.cache removeObjectForKey:key];
    @synchronized (self.trackedKeys) { [self.trackedKeys removeObject:key]; }
    self.currentEntryCount = self.trackedKeys.count;
}

- (void)removeAllObjects {
    [self.cache removeAllObjects];
    @synchronized (self.trackedKeys) { [self.trackedKeys removeAllObjects]; }
    self.currentEntryCount = 0;
}

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    // NSCache 自动淘汰时同步追踪
    @synchronized (self.trackedKeys) {
        [self.trackedKeys filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *key, id bindings) {
            return [cache objectForKey:key] != nil;
        }]];
    }
    self.currentEntryCount = self.trackedKeys.count;
}

- (void)prewarmCommonAssets {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // 预热常用颜色对象
        UIColor *brandColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.62 alpha:1.0];
        [self.cache setObject:brandColor forKey:@"brand_color" cost:0];

        UIColor *glassWhite = [UIColor colorWithWhite:1.0 alpha:0.08];
        [self.cache setObject:glassWhite forKey:@"glass_tint" cost:0];

        NSLog(@"[小杳知] 缓存预热完成");
    });
}

- (void)purgeOnMemoryWarning {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        // 保留核心缓存，清除一半
        self.cache.totalCostLimit = self.cache.totalCostLimit / 2;
        self.cache.countLimit = MAX(5, self.cache.countLimit / 2);
        [self.cache removeAllObjects];

        // 恢复限制
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.cache.totalCostLimit = self.maxCacheSizeMB * 1024 * 1024;
            self.cache.countLimit = self.maxEntryCount;
        });

        NSLog(@"[小杳知] 内存警告: 缓存已减半");
    });
}

- (void)handleMemoryWarning {
    [self purgeOnMemoryWarning];
}

@end
