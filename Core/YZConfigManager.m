#import "YZConfigManager.h"

static NSString *const kYZConfigSuiteName = @"com.rouneed.xiaoyaozhi";

// 默认配置
static NSDictionary *sDefaultConfig = nil;

@implementation YZConfigManager

+ (instancetype)shared {
    static YZConfigManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YZConfigManager alloc] init];
    });
    return instance;
}

+ (void)loadConfiguration {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sDefaultConfig = @{
            @"plugin_active": @YES,
            @"glass_effect_enabled": @YES,
            @"particle_effect_enabled": @YES,
            @"haptic_feedback_enabled": @YES,
            @"animation_speed": @"normal",
            @"sheet_damping_ratio": @0.65,
            @"sheet_animation_duration": @0.55,
            @"button_damping_ratio": @0.55,
            @"button_animation_duration": @0.35,
            @"max_cache_size_mb": @8,
            @"max_cache_entries": @50,
            @"max_clarification_rounds": @3,
            @"welcome_message_shown": @NO,
            @"version": @"1.3.7"
        };

        // 用已保存的用户配置覆盖默认值
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYZConfigSuiteName];
        NSDictionary *saved = [defaults dictionaryForKey:@"plugin_config"];
        if (saved) {
            NSMutableDictionary *merged = [sDefaultConfig mutableCopy];
            [merged addEntriesFromDictionary:saved];
            sDefaultConfig = [merged copy];
        }

        NSLog(@"[小杳知] 配置加载完成, %lu 项", (unsigned long)sDefaultConfig.count);
    });
}

- (id)valueForKey:(NSString *)key {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYZConfigSuiteName];
    id saved = [defaults objectForKey:key];
    if (saved) return saved;
    return sDefaultConfig[key];
}

- (NSString *)stringForKey:(NSString *)key {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:NSString.class]) return value;
    return nil;
}

- (BOOL)boolForKey:(NSString *)key {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:NSNumber.class]) return [value boolValue];
    return NO;
}

- (NSInteger)integerForKey:(NSString *)key {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:NSNumber.class]) return [value integerValue];
    return 0;
}

- (CGFloat)floatForKey:(NSString *)key {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:NSNumber.class]) return [value doubleValue];
    return 0.0;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if (!key || !value) return;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYZConfigSuiteName];
    NSMutableDictionary *config = [[defaults dictionaryForKey:@"plugin_config"] mutableCopy] ?: [NSMutableDictionary dictionary];
    config[key] = value;
    [defaults setObject:config forKey:@"plugin_config"];
    [defaults synchronize];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self setValue:@(value) forKey:key];
}

- (void)resetToDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYZConfigSuiteName];
    [defaults removeObjectForKey:@"plugin_config"];
    [defaults synchronize];
}

- (NSDictionary *)exportConfig {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYZConfigSuiteName];
    NSDictionary *saved = [defaults dictionaryForKey:@"plugin_config"];
    NSMutableDictionary *merged = [sDefaultConfig mutableCopy];
    if (saved) {
        [merged addEntriesFromDictionary:saved];
    }
    // 移除内部字段
    [merged removeObjectForKey:@"version"];
    return [merged copy];
}

@end
