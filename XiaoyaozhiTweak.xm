// 小杳知 - iOS 26 液态风格微信增强插件
// 目标: com.tencent.xin / com.tencent.qy.xin / com.tencent.wx
// 集成: 老猫的插件管理 / libsubstrate.dylib
// 最低系统: iOS 14.0
// 架构: arm64 / arm64e (rootless)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

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

@interface YZBlockTarget : NSObject
@property (nonatomic, copy) dispatch_block_t block;
- (instancetype)initWithBlock:(dispatch_block_t)block;
- (void)invoke;
@end

@implementation YZBlockTarget

- (instancetype)initWithBlock:(dispatch_block_t)block {
    self = [super init];
    if (self) {
        _block = [block copy];
    }
    return self;
}

- (void)invoke {
    if (self.block) self.block();
}

@end

// ============================================================
// MARK: - 常量
// ============================================================

static NSString *const kYZPluginActivationKey = @"Xiaoyaozhi_LastActivation";
static NSString *const kYZInstallFingerprintKey = @"Xiaoyaozhi_LastInstallSuccessFingerprint";
static NSTimeInterval const kYZInstallAlertDelay = 1.2;
static BOOL gYZIsPluginLoaded = NO;
static YZGlassSheetController *gSheetController = nil;
static BOOL gYZInstallAlertScheduled = NO;
static BOOL gYZInstallAlertVisible = NO;
static id gYZBecomeActiveToken = nil;
static id gYZDidLoadToken = nil;
static id gYZWillUnloadToken = nil;
static id gYZMemoryWarningToken = nil;
static char kYZInstallDismissTargetKey;

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

static NSString *YZCurrentInstallFingerprint(void) {
    NSString *version = [[YZPluginLifecycle sharedInstance] pluginVersion] ?: @"unknown";
    NSString *executablePath = NSBundle.mainBundle.executablePath;
    NSDictionary<NSFileAttributeKey, id> *executableAttrs = executablePath.length > 0
        ? [NSFileManager.defaultManager attributesOfItemAtPath:executablePath error:nil]
        : nil;
    NSDate *executableModifiedDate = executableAttrs[NSFileModificationDate];
    NSNumber *executableSize = executableAttrs[NSFileSize] ?: @0;
    NSTimeInterval executableModifiedAt = executableModifiedDate ? executableModifiedDate.timeIntervalSince1970 : 0;

    Dl_info imageInfo;
    NSString *imagePath = nil;
    if (dladdr((const void *)&YZCurrentInstallFingerprint, &imageInfo) && imageInfo.dli_fname) {
        imagePath = [NSString stringWithUTF8String:imageInfo.dli_fname];
    }
    NSDictionary<NSFileAttributeKey, id> *imageAttrs = imagePath.length > 0
        ? [NSFileManager.defaultManager attributesOfItemAtPath:imagePath error:nil]
        : nil;
    NSDate *imageModifiedDate = imageAttrs[NSFileModificationDate];
    NSNumber *imageSize = imageAttrs[NSFileSize] ?: @0;
    NSTimeInterval imageModifiedAt = imageModifiedDate ? imageModifiedDate.timeIntervalSince1970 : 0;

    return [NSString stringWithFormat:@"%@|%.0f|%@|%.0f|%@",
                                      version,
                                      executableModifiedAt,
                                      executableSize,
                                      imageModifiedAt,
                                      imageSize];
}

static BOOL YZNeedsInstallSuccessAlert(NSUserDefaults *defaults, NSString **fingerprintOut) {
    NSString *fingerprint = YZCurrentInstallFingerprint();
    if (fingerprintOut) *fingerprintOut = fingerprint;
    NSString *lastFingerprint = [defaults stringForKey:kYZInstallFingerprintKey];
    return fingerprint.length > 0 && ![lastFingerprint isEqualToString:fingerprint];
}

static void YZShowInstallSuccessAlertIfNeeded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gYZInstallAlertVisible) return;

        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.rouneed.xiaoyaozhi"];
        NSString *fingerprint = nil;
        if (!YZNeedsInstallSuccessAlert(defaults, &fingerprint)) {
            gYZInstallAlertScheduled = NO;
            return;
        }

        UIWindow *window = YZKeyWindow();
        if (!window) {
            gYZInstallAlertScheduled = NO;
            return;
        }
        if (![YZCrashGuard checkAndLogCrashForLocation:@"installSuccessAlert"]) {
            gYZInstallAlertScheduled = NO;
            return;
        }

        gYZInstallAlertVisible = YES;
        [defaults setObject:fingerprint forKey:kYZInstallFingerprintKey];
        [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kYZPluginActivationKey];
        [defaults synchronize];

        UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
        overlay.alpha = 0.0;

        UIBlurEffect *blurEffect;
        if (@available(iOS 13.0, *)) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
        } else {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = overlay.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.alpha = 0.82;
        [overlay addSubview:blurView];

        CGFloat width = MIN(CGRectGetWidth(window.bounds) - 48.0, 320.0);
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 300.0)];
        card.center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
        card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.94];
        card.layer.cornerRadius = 28.0;
        card.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
        card.layer.shadowOpacity = 0.12;
        card.layer.shadowRadius = 28.0;
        card.layer.shadowOffset = CGSizeMake(0, 14);
        card.transform = CGAffineTransformMakeScale(0.94, 0.94);
        [overlay addSubview:card];

        UIView *iconShell = [[UIView alloc] initWithFrame:CGRectMake((width - 72.0) / 2.0, 26.0, 72.0, 72.0)];
        iconShell.backgroundColor = [UIColor colorWithRed:0.86 green:0.93 blue:1.0 alpha:1.0];
        iconShell.layer.cornerRadius = 22.0;
        iconShell.layer.borderWidth = 5.0;
        iconShell.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
        [card addSubview:iconShell];

        UILabel *checkLabel = [[UILabel alloc] initWithFrame:iconShell.bounds];
        checkLabel.text = @"✓";
        checkLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
        checkLabel.textAlignment = NSTextAlignmentCenter;
        checkLabel.textColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
        [iconShell addSubview:checkLabel];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24.0, 112.0, width - 48.0, 30.0)];
        titleLabel.text = @"完美安装完成";
        titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0];
        [card addSubview:titleLabel];

        UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(28.0, 150.0, width - 56.0, 44.0)];
        messageLabel.text = @"小杳知已随本次签名覆盖生效，打开微信即可开始使用。";
        messageLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.textColor = [UIColor colorWithWhite:0.36 alpha:1.0];
        messageLabel.numberOfLines = 2;
        [card addSubview:messageLabel];

        UILabel *versionPill = [[UILabel alloc] initWithFrame:CGRectMake((width - 118.0) / 2.0, 202.0, 118.0, 28.0)];
        versionPill.text = [NSString stringWithFormat:@"Version %@", [[YZPluginLifecycle sharedInstance] pluginVersion]];
        versionPill.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        versionPill.textAlignment = NSTextAlignmentCenter;
        versionPill.textColor = [UIColor colorWithWhite:0.42 alpha:1.0];
        versionPill.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
        versionPill.layer.cornerRadius = 14.0;
        versionPill.clipsToBounds = YES;
        [card addSubview:versionPill];

        UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
        doneButton.frame = CGRectMake(24.0, 238.0, width - 48.0, 42.0);
        doneButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
        doneButton.layer.cornerRadius = 16.0;
        doneButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [doneButton setTitle:@"开始体验" forState:UIControlStateNormal];
        [doneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [card addSubview:doneButton];

        __weak UIView *weakOverlay = overlay;
        __weak UIView *weakCard = card;
        __weak UIButton *weakButton = doneButton;
        YZBlockTarget *target = [[YZBlockTarget alloc] initWithBlock:^{
            UIView *strongOverlay = weakOverlay;
            UIView *strongCard = weakCard;
            UIButton *strongButton = weakButton;
            if (strongButton) {
                objc_setAssociatedObject(strongButton, &kYZInstallDismissTargetKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }

            [UIView animateWithDuration:0.22 animations:^{
                strongOverlay.alpha = 0.0;
                strongCard.transform = CGAffineTransformMakeScale(0.96, 0.96);
            } completion:^(__unused BOOL finished) {
                [strongOverlay removeFromSuperview];
                gYZInstallAlertVisible = NO;
                gYZInstallAlertScheduled = NO;
            }];
        }];
        objc_setAssociatedObject(doneButton, &kYZInstallDismissTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [doneButton addTarget:target action:@selector(invoke) forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:overlay];
        [UIView animateWithDuration:0.32
                              delay:0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            overlay.alpha = 1.0;
            card.transform = CGAffineTransformIdentity;
        } completion:nil];
    });
}

static void YZScheduleInstallSuccessAlertIfNeeded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gYZInstallAlertScheduled || gYZInstallAlertVisible) return;
        if (![[YZPluginLifecycle sharedInstance] isPluginActive]) return;

        gYZInstallAlertScheduled = YES;
        [YZAsyncExecutor executeAfterDelay:kYZInstallAlertDelay block:^{
            YZShowInstallSuccessAlertIfNeeded();
        }];
    });
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
                YZScheduleInstallSuccessAlertIfNeeded();
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
            YZScheduleInstallSuccessAlertIfNeeded();
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

    YZScheduleInstallSuccessAlertIfNeeded();
}

%end
