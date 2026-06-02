#import "YZPluginLifecycle.h"
#import "YZGlassSheetController.h"
#import <UIKit/UIKit.h>

NSString *const kYZPluginDidLoadNotification = @"com.rouneed.xiaoyaozhi.pluginDidLoad";
NSString *const kYZPluginWillUnloadNotification = @"com.rouneed.xiaoyaozhi.pluginWillUnload";
NSString *const kYZPluginDidEnterBackgroundNotification = @"com.rouneed.xiaoyaozhi.didEnterBackground";
NSString *const kYZPluginWillEnterForegroundNotification = @"com.rouneed.xiaoyaozhi.willEnterForeground";

@interface YZPluginLifecycle () <XiaoyaozhiPluginProtocol>
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, copy) NSString *managerName;
@end

@implementation YZPluginLifecycle

- (BOOL)storedPluginActive {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.rouneed.xiaoyaozhi"];
    id savedActive = [defaults objectForKey:@"plugin_active"];
    return savedActive ? [savedActive boolValue] : YES;
}

+ (instancetype)sharedInstance {
    static YZPluginLifecycle *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YZPluginLifecycle alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isActive = [self storedPluginActive];
        _managerName = @"老猫的插件管理";
    }
    return self;
}

- (NSString *)pluginIdentifier {
    return @"com.rouneed.xiaoyaozhi";
}

- (NSString *)pluginVersion {
    return @"1.2.3";
}

- (NSString *)pluginDisplayName {
    return @"小杳知";
}

- (void)registerWithManager:(NSString *)managerName {
    self.managerName = managerName ?: @"老猫的插件管理";
    NSLog(@"[小杳知] 已注册到 %@", self.managerName);

    [self pluginDidLoad];

    [[NSNotificationCenter defaultCenter] postNotificationName:kYZPluginDidLoadNotification object:self];
}

- (void)pluginDidLoad {
    self.isActive = [self storedPluginActive];
    NSLog(@"[小杳知] 插件已加载 v%@", [self pluginVersion]);

    // 监听应用生命周期
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)pluginWillUnload {
    self.isActive = NO;
    NSLog(@"[小杳知] 插件即将卸载");

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:kYZPluginWillUnloadNotification object:self];
}

- (void)applicationDidEnterBackground {
    if (!self.isActive) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:kYZPluginDidEnterBackgroundNotification object:self];
}

- (void)applicationWillEnterForeground {
    if (!self.isActive) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:kYZPluginWillEnterForegroundNotification object:self];
}

- (BOOL)isPluginActive {
    return self.isActive;
}

- (void)setPluginActive:(BOOL)active {
    if (_isActive == active) return;
    _isActive = active;
    NSLog(@"[小杳知] 插件状态: %@", active ? @"启用" : @"禁用");

    // 通知老猫插件管理框架状态变更
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.rouneed.xiaoyaozhi"];
    [defaults setBool:active forKey:@"plugin_active"];
    [defaults synchronize];
}

- (UIViewController *)settingsViewController {
    return [[YZGlassSheetController alloc] init];
}

- (BOOL)handleURLScheme:(NSURL *)url {
    return [url.scheme.lowercaseString isEqualToString:@"xiaoyaozhi"];
}

@end

@implementation XiaoyaozhiPlugin

+ (instancetype)sharedInstance {
    static XiaoyaozhiPlugin *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XiaoyaozhiPlugin alloc] init];
    });
    return instance;
}

- (NSString *)pluginIdentifier {
    return [[YZPluginLifecycle sharedInstance] pluginIdentifier];
}

- (NSString *)pluginVersion {
    return [[YZPluginLifecycle sharedInstance] pluginVersion];
}

- (NSString *)pluginDisplayName {
    return [[YZPluginLifecycle sharedInstance] pluginDisplayName];
}

- (void)pluginDidLoad {
    [[YZPluginLifecycle sharedInstance] pluginDidLoad];
}

- (void)pluginWillUnload {
    [[YZPluginLifecycle sharedInstance] pluginWillUnload];
}

- (UIViewController *)settingsViewController {
    return [[YZPluginLifecycle sharedInstance] settingsViewController];
}

- (BOOL)handleURLScheme:(NSURL *)url {
    return [[YZPluginLifecycle sharedInstance] handleURLScheme:url];
}

@end
