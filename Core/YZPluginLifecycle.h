#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 小杳知插件协议 - 供老猫插件管理框架调用
@protocol XiaoyaozhiPluginProtocol <NSObject>
@required
- (NSString *)pluginIdentifier;
- (NSString *)pluginVersion;
- (NSString *)pluginDisplayName;
- (void)pluginDidLoad;
- (void)pluginWillUnload;
@optional
- (UIViewController *)settingsViewController;
- (BOOL)handleURLScheme:(NSURL *)url;
@end

// 插件生命周期通知
extern NSString *const kYZPluginDidLoadNotification;
extern NSString *const kYZPluginWillUnloadNotification;
extern NSString *const kYZPluginDidEnterBackgroundNotification;
extern NSString *const kYZPluginWillEnterForegroundNotification;

@interface YZPluginLifecycle : NSObject

@property (class, nonatomic, readonly) YZPluginLifecycle *sharedInstance;

- (NSString *)pluginIdentifier;
- (NSString *)pluginVersion;
- (NSString *)pluginDisplayName;

- (void)registerWithManager:(NSString *)managerName;
- (void)pluginDidLoad;
- (void)pluginWillUnload;

- (BOOL)isPluginActive;
- (void)setPluginActive:(BOOL)active;

- (UIViewController *)settingsViewController;
- (BOOL)handleURLScheme:(NSURL *)url;

@end

@interface XiaoyaozhiPlugin : NSObject <XiaoyaozhiPluginProtocol>

@property (class, nonatomic, readonly) XiaoyaozhiPlugin *sharedInstance;

@end
