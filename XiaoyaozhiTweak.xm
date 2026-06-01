// 小杳知 - iOS 26 液态风格微信增强插件
// 目标: com.tencent.xin / com.tencent.qy.xin / com.tencent.wx
// 集成: 老猫的插件管理 / libsubstrate.dylib
// 最低系统: iOS 14.0
// 架构: arm64 / arm64e (rootless)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "Core/YZPluginLifecycle.h"
#import "Core/YZEnvironmentDetector.h"
#import "Core/YZConfigManager.h"
#import "UI/YZGlassSheetController.h"
#import "UI/YZAnimator.h"
#import "WeChat/YZWCRuntime.h"
#import "Optimizer/YZAsyncExecutor.h"
#import "Optimizer/YZMemoryCache.h"
#import "Guard/YZCrashGuard.h"
#import "Guard/YZPrivacyGuard.h"

// ============================================================
// MARK: - 常量
// ============================================================

static NSString *const kYZPluginActivationKey = @"Xiaoyaozhi_LastActivation";
static NSTimeInterval const kYZInitialDelay = 3.0;
static BOOL gYZIsPluginLoaded = NO;
static YZGlassSheetController *gSheetController = nil;
static id gYZBecomeActiveToken = nil;
static id gYZDidLoadToken = nil;
static id gYZWillUnloadToken = nil;
static id gYZMemoryWarningToken = nil;

// ============================================================
// MARK: - 工具函数
// ============================================================

static BOOL YZIsTargetBundle(void) {
    return [YZWCRuntime isWeChatBundle];
}

static __attribute__((unused)) UIWindow *YZKeyWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;

            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow && window.rootViewController) return window;
            }
        }
    }

    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow && window.rootViewController) return window;
    }

    return app.windows.firstObject;
}

static void YZShowGlassSheet(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 内存警告时取消展示
        if (NSProcessInfo.processInfo.isLowPowerModeEnabled) return;

        // 防止重复弹出
        if (gSheetController && gSheetController.isPresented) return;

        if (![YZCrashGuard checkAndLogCrashForLocation:@"showSheet"]) return;

        gSheetController = [[YZGlassSheetController alloc] init];
        [gSheetController presentFromTopViewController];

        // 更新激活时间戳
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.rouneed.xiaoyaozhi"];
        [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kYZPluginActivationKey];
        [defaults synchronize];
    });
}

// ============================================================
// MARK: - 插件初始化
// ============================================================

__attribute__((constructor))
static void YZXiaoyaozhiInit(void) {
    @autoreleasepool {
        // 0. 非微信环境不加载
        if (!YZIsTargetBundle()) return;

        // ====== 阶段 1: 同步最小初始化 (< 5ms) ======
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

        // 注册崩溃防护（最先执行）
        [YZCrashGuard registerAll];

        // 环境检测
        [[YZEnvironmentDetector shared] self]; // 触发懒加载检测

        // 隐私审计（仅记录，不阻塞加载）
        [[YZPrivacyGuard performPrivacyAudit] self];

        CFAbsoluteTime syncTime = CFAbsoluteTimeGetCurrent() - startTime;
        NSLog(@"[小杳知] 阶段1 同步初始化: %.1fms", syncTime * 1000);

        // ====== 阶段 2: 异步加载非关键资源 ======
        [YZAsyncExecutor executeOnBackground:^{
            [YZConfigManager loadConfiguration];
            [[YZMemoryCache shared] prewarmCommonAssets];

            // 生成隐私报告（调试用）
#ifndef NDEBUG
            NSString *report = [YZPrivacyGuard generatePrivacyReport];
            NSLog(@"[小杳知] 隐私报告:\n%@", report);
#endif
        }];

        // ====== 阶段 3: 主线程初始化 ======
        dispatch_async(dispatch_get_main_queue(), ^{
            CFAbsoluteTime mainStartTime = CFAbsoluteTimeGetCurrent();

            // 注册到老猫的插件管理
            [[YZPluginLifecycle sharedInstance] registerWithManager:@"老猫的插件管理"];

            // 监听（保存 token 以便卸载时移除）
            NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;

            gYZBecomeActiveToken = [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(__unused NSNotification *note) {
                [YZAsyncExecutor executeAfterDelay:kYZInitialDelay block:^{
                    if ([[YZPluginLifecycle sharedInstance] isPluginActive]) YZShowGlassSheet();
                }];
            }];

            gYZDidLoadToken = [nc addObserverForName:kYZPluginDidLoadNotification
                                               object:nil queue:[NSOperationQueue mainQueue]
                                           usingBlock:^(__unused NSNotification *note) { gYZIsPluginLoaded = YES; }];

            gYZWillUnloadToken = [nc addObserverForName:kYZPluginWillUnloadNotification
                                                  object:nil queue:[NSOperationQueue mainQueue]
                                              usingBlock:^(__unused NSNotification *note) {
                gYZIsPluginLoaded = NO;
                if (gSheetController && gSheetController.isPresented) { [gSheetController dismissAnimated]; gSheetController = nil; }
                [[YZMemoryCache shared] removeAllObjects];
                // 移除所有 observer
                NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
                if (gYZBecomeActiveToken) { [center removeObserver:gYZBecomeActiveToken]; gYZBecomeActiveToken = nil; }
                if (gYZDidLoadToken) { [center removeObserver:gYZDidLoadToken]; gYZDidLoadToken = nil; }
                if (gYZWillUnloadToken) { [center removeObserver:gYZWillUnloadToken]; gYZWillUnloadToken = nil; }
                if (gYZMemoryWarningToken) { [center removeObserver:gYZMemoryWarningToken]; gYZMemoryWarningToken = nil; }
            }];

            gYZMemoryWarningToken = [nc addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                     object:nil queue:[NSOperationQueue mainQueue]
                                                 usingBlock:^(__unused NSNotification *note) {
                [[YZMemoryCache shared] purgeOnMemoryWarning];
                if (gSheetController && !gSheetController.isPresented) gSheetController = nil;
            }];

            CFAbsoluteTime mainTime = CFAbsoluteTimeGetCurrent() - mainStartTime;
            NSLog(@"[小杳知] 阶段3 主线程初始化: %.1fms | 总: %.1fms",
                  mainTime * 1000,
                  (CFAbsoluteTimeGetCurrent() - startTime) * 1000);

            gYZIsPluginLoaded = YES;
            NSLog(@"[小杳知] ✅ 插件加载完成 v%@ | iOS %ld | %@",
                  [[YZPluginLifecycle sharedInstance] pluginVersion],
                  (long)[YZEnvironmentDetector shared].iOSMajorVersion,
                  [YZEnvironmentDetector shared].supportsLiquidGlass ? @"液态玻璃" : @"兼容模式");
        });
    }
}

// ============================================================
// MARK: - Logos Hook
// ============================================================

// Hook 微信的 applicationDidBecomeActive 确保在微信完全启动后再展示
%hook AppDelegate

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;

    if (![[YZPluginLifecycle sharedInstance] isPluginActive]) return;

    // 延迟展示，确保微信 UI 完全就绪
    [YZAsyncExecutor executeAfterDelay:kYZInitialDelay block:^{
        YZShowGlassSheet();
    }];
}

%end
