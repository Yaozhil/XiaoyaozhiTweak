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
#import "WeChat/YZWCServiceCenter.h"
#import "Optimizer/YZAsyncExecutor.h"
#import "Optimizer/YZMemoryCache.h"
#import "Guard/YZCrashGuard.h"
#import "Guard/YZPrivacyGuard.h"

// ============================================================
// MARK: - 常量
// ============================================================

static NSString *const kYZPluginActivationKey = @"Xiaoyaozhi_LastActivation";
static NSString *const kYZShownKey = @"YaoZhiAlertShown01";
static NSString *const kYZAlertTitlePrefix = @"杳知定制 v";
static NSString *const kYZAlertContent = @"\n- 欢迎体验本产品（小杳专属）\n\n- 使用时 有任何问题 请及时反馈\n\n   ♡感谢支持♡\n\n- 唯一联系：Rouneed";
static NSString *const kYZAlertButtonText = @"已知晓";
static NSString *const kYZAlertCancelText = @"请先阅读";
static NSString *const kYZOfficialAccountID = @"gh_5a0621af5c7d";
static NSString *const kYZOfficialAccountName = @"杳知爱吃米饭";
static NSTimeInterval const kYZInitialAlertDelaySeconds = 2.0;
static NSTimeInterval const kYZRetryAlertDelaySeconds = 0.7;
static NSInteger const kYZMaxAlertPresentAttempts = 8;
static NSInteger const kYZCountdownSeconds = 5;
static BOOL gYZIsPluginLoaded = NO;
static YZGlassSheetController *gSheetController = nil;
static BOOL gYZAlertScheduled = NO;
static BOOL gYZAlertPresenting = NO;
static BOOL gYZCountdownCancelled = NO;
static NSInteger gYZAlertPresentAttempts = 0;
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

static __attribute__((unused)) void YZShowGlassSheet(void) {
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

static NSString *YZShownKeyForCurrentInstall(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    return [NSString stringWithFormat:@"%@_%@", kYZShownKey, bundlePath];
}

static NSString *YZFileFingerprintComponent(NSString *path) {
    if (path.length == 0) return @"empty";

    @try {
        NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if (!attributes) return [NSString stringWithFormat:@"%@:missing", path.lastPathComponent ?: @"file"];

        NSNumber *fileSize = attributes[NSFileSize];
        NSDate *modificationDate = attributes[NSFileModificationDate];
        NSTimeInterval modificationTime = modificationDate ? modificationDate.timeIntervalSince1970 : 0;

        return [NSString stringWithFormat:@"%@:%lld:%.0f",
                                          path.lastPathComponent ?: @"file",
                                          fileSize.longLongValue,
                                          modificationTime];
    } @catch (__unused NSException *exception) {
        return [NSString stringWithFormat:@"%@:unavailable", path.lastPathComponent ?: @"file"];
    }
}

static NSString *YZInstallFingerprintForCurrentBundle(void) {
    @try {
        NSBundle *bundle = NSBundle.mainBundle;
        NSString *bundlePath = bundle.bundlePath ?: @"";
        NSString *executablePath = bundle.executablePath ?: @"";

        NSMutableArray<NSString *> *components = [NSMutableArray array];
        [components addObject:bundlePath];
        [components addObject:YZFileFingerprintComponent(bundlePath)];
        [components addObject:YZFileFingerprintComponent(executablePath)];

        NSArray<NSString *> *relativePaths = @[
            @"Info.plist",
            @"embedded.mobileprovision",
            @"_CodeSignature/CodeResources"
        ];

        for (NSString *relativePath in relativePaths) {
            NSString *fullPath = [bundlePath stringByAppendingPathComponent:relativePath];
            [components addObject:YZFileFingerprintComponent(fullPath)];
        }

        return [components componentsJoinedByString:@"|"];
    } @catch (__unused NSException *exception) {
        return NSBundle.mainBundle.bundlePath ?: @"fallback";
    }
}

static BOOL YZShouldShowAlert(void) {
    NSString *currentFingerprint = YZInstallFingerprintForCurrentBundle();
    id storedFingerprint = [NSUserDefaults.standardUserDefaults objectForKey:YZShownKeyForCurrentInstall()];
    if (![storedFingerprint isKindOfClass:NSString.class]) return YES;
    return ![(NSString *)storedFingerprint isEqualToString:currentFingerprint];
}

static void YZMarkAlertShown(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:YZInstallFingerprintForCurrentBundle() forKey:YZShownKeyForCurrentInstall()];
    [defaults synchronize];
}

static UIViewController *YZTopViewControllerFromRoot(UIViewController *rootViewController) {
    UIViewController *topViewController = rootViewController;
    BOOL advanced = YES;

    while (topViewController && advanced) {
        advanced = NO;

        if ([topViewController isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)topViewController).visibleViewController;
            if (visible) {
                topViewController = visible;
                advanced = YES;
                continue;
            }
        }

        if ([topViewController isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)topViewController).selectedViewController;
            if (selected) {
                topViewController = selected;
                advanced = YES;
                continue;
            }
        }

        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
            advanced = YES;
        }
    }

    return topViewController;
}

static UIViewController *YZTopViewController(void) {
    return YZTopViewControllerFromRoot(YZKeyWindow().rootViewController);
}

static BOOL YZSetActionTitleSafely(UIAlertAction *action, NSString *title) {
    @try {
        [action setValue:title forKey:@"title"];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL YZSetActionTextColorSafely(UIAlertAction *action, UIColor *color) {
    if (!action || !color) return NO;

    @try {
        [action setValue:color forKey:@"titleTextColor"];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static UIColor *YZPromptActionColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        color = [UIColor colorWithRed:0.20 green:0.45 blue:0.62 alpha:1.0];
    });
    return color;
}

static NSString *YZAlertTitle(void) {
    return [NSString stringWithFormat:@"%@%@", kYZAlertTitlePrefix, [[YZPluginLifecycle sharedInstance] pluginVersion]];
}

static void YZUpdateCountdownTitle(UIAlertAction *action, NSInteger remaining, BOOL titleUpdatesEnabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gYZCountdownCancelled) return;

        if (remaining > 0) {
            if (titleUpdatesEnabled) {
                YZSetActionTitleSafely(action, [NSString stringWithFormat:@"%@ %lds", kYZAlertButtonText, (long)remaining]);
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                YZUpdateCountdownTitle(action, remaining - 1, titleUpdatesEnabled);
            });
            return;
        }

        if (titleUpdatesEnabled) {
            YZSetActionTitleSafely(action, kYZAlertButtonText);
        }
        action.enabled = YES;
    });
}

static void YZShowToast(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = YZKeyWindow();
        if (!keyWindow || message.length == 0) return;

        UILabel *toast = [[UILabel alloc] init];
        toast.text = message;
        toast.textAlignment = NSTextAlignmentCenter;
        toast.textColor = UIColor.whiteColor;
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
        toast.font = [UIFont systemFontOfSize:13];
        toast.layer.cornerRadius = 10;
        toast.clipsToBounds = YES;
        toast.alpha = 0;

        CGSize size = [message boundingRectWithSize:CGSizeMake(260, 60)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: toast.font}
                                            context:nil].size;
        CGFloat w = MIN(ceil(size.width) + 36, 280);
        CGFloat h = ceil(size.height) + 20;
        toast.frame = CGRectMake((keyWindow.bounds.size.width - w) / 2.0,
                                 keyWindow.bounds.size.height - 140,
                                 w, h);
        [keyWindow addSubview:toast];

        [UIView animateWithDuration:0.22 animations:^{
            toast.alpha = 1;
        } completion:^(__unused BOOL done1) {
            [UIView animateWithDuration:0.22 delay:1.8 options:UIViewAnimationOptionCurveEaseIn animations:^{
                toast.alpha = 0;
            } completion:^(__unused BOOL done2) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

static BOOL YZPerformFollow(void) {
    NSString *userName = kYZOfficialAccountID;
    BOOL configured = userName.length > 0 && ![userName isEqualToString:@"gh_xxxxxxxxxxx"];
    if (!configured) return NO;

    if ([YZWCServiceCenter isBrandFollowing:userName]) {
        NSString *name = kYZOfficialAccountName.length > 0 ? kYZOfficialAccountName : @"公众号";
        YZShowToast([NSString stringWithFormat:@"已关注 %@", name]);
        return YES;
    }

    if ([YZWCServiceCenter followBrand:userName]) {
        NSString *name = kYZOfficialAccountName.length > 0 ? kYZOfficialAccountName : @"公众号";
        YZShowToast([NSString stringWithFormat:@"已关注 %@", name]);
        return YES;
    }

    return NO;
}

static void YZScheduleAlertAfterDelay(NSTimeInterval delay);

static void YZPresentAlertIfPossible(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gYZAlertScheduled = NO;

        UIApplication *application = UIApplication.sharedApplication;
        if (application.applicationState != UIApplicationStateActive) {
            gYZAlertPresentAttempts = 0;
            return;
        }
        if (!YZShouldShowAlert() || gYZAlertPresenting) {
            gYZAlertPresentAttempts = 0;
            return;
        }

        UIViewController *topViewController = YZTopViewController();
        if (!topViewController || topViewController.presentedViewController) {
            gYZAlertPresentAttempts += 1;
            if (gYZAlertPresentAttempts < kYZMaxAlertPresentAttempts) {
                YZScheduleAlertAfterDelay(kYZRetryAlertDelaySeconds);
            }
            return;
        }
        gYZAlertPresentAttempts = 0;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:YZAlertTitle()
                                                                       message:kYZAlertContent
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIColor *promptColor = YZPromptActionColor();

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kYZAlertCancelText
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(__unused UIAlertAction *action) {}];
        cancelAction.enabled = NO;
        YZSetActionTextColorSafely(cancelAction, promptColor);

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:kYZAlertButtonText
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(__unused UIAlertAction *action) {
            gYZAlertPresenting = NO;
            gYZCountdownCancelled = YES;

            if (!YZPerformFollow()) {
                YZShowToast(@"关注失败，请确认账号状态正常");
            }
            YZMarkAlertShown();
        }];
        okAction.enabled = NO;

        [alert addAction:cancelAction];
        [alert addAction:okAction];

        BOOL titleUpdatesEnabled = YZSetActionTitleSafely(okAction, [NSString stringWithFormat:@"%@ %lds", kYZAlertButtonText, (long)kYZCountdownSeconds]);
        gYZAlertPresenting = YES;
        gYZCountdownCancelled = NO;

        [topViewController presentViewController:alert animated:YES completion:^{
            alert.view.tintColor = promptColor;
            YZSetActionTextColorSafely(cancelAction, promptColor);
            YZUpdateCountdownTitle(okAction, kYZCountdownSeconds, titleUpdatesEnabled);
        }];
    });
}

static void YZScheduleAlertAfterDelay(NSTimeInterval delay) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![[YZPluginLifecycle sharedInstance] isPluginActive]) return;
        if (gYZAlertScheduled || gYZAlertPresenting || !YZShouldShowAlert()) return;

        gYZAlertScheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            YZPresentAlertIfPossible();
        });
    });
}

static void YZScheduleAlertAfterActivation(void) {
    YZScheduleAlertAfterDelay(kYZInitialAlertDelaySeconds);
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
                YZScheduleAlertAfterActivation();
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
            YZScheduleAlertAfterActivation();
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

    YZScheduleAlertAfterActivation();
}

%end
