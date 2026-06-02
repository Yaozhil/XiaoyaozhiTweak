#import "YZEnvironmentDetector.h"

@interface YZEnvironmentDetector ()
@property (nonatomic, readwrite) NSInteger iOSMajorVersion;
@property (nonatomic, readwrite) YZDeviceModel deviceModel;
@property (nonatomic, readwrite) YZDisplayType displayType;
@property (nonatomic, readwrite) BOOL supportsLiquidGlass;
@property (nonatomic, readwrite) BOOL isLowPowerMode;
@end

@implementation YZEnvironmentDetector

static UIWindow *YZEnvironmentCurrentWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        UIWindow *fallbackWindow = nil;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!fallbackWindow) fallbackWindow = window;
            if (window.isKeyWindow) return window;
        }
        if (fallbackWindow) return fallbackWindow;
    }

    id<UIApplicationDelegate> delegate = app.delegate;
    if ([delegate respondsToSelector:@selector(window)]) return delegate.window;
    return nil;
}

+ (instancetype)shared {
    static YZEnvironmentDetector *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YZEnvironmentDetector alloc] init];
        [instance detectEnvironment];
    });
    return instance;
}

- (void)detectEnvironment {
    // 阶段1: 无 UI 依赖的检测（构造器安全）
    NSString *versionString = UIDevice.currentDevice.systemVersion;
    self.iOSMajorVersion = [[versionString componentsSeparatedByString:@"."].firstObject integerValue];
    self.supportsLiquidGlass = (self.iOSMajorVersion >= 26);

    switch (UIDevice.currentDevice.userInterfaceIdiom) {
        case UIUserInterfaceIdiomPad:
            self.deviceModel = YZDeviceModeliPad;
            self.displayType = YZDisplayTypeiPad;
            break;
        case UIUserInterfaceIdiomPhone:
        default:
            self.deviceModel = YZDeviceModeliPhone;
            break;
    }

    self.isLowPowerMode = NSProcessInfo.processInfo.isLowPowerModeEnabled;

    // 阶段2: 全面屏检测延迟到主线程 UI 就绪后
    if (self.deviceModel == YZDeviceModeliPhone) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self detectDisplayType];
        });
    }

    NSLog(@"[小杳知] 环境检测: iOS %ld | 液态玻璃: %@ | 屏幕类型: %ld | 低功耗: %@",
          (long)self.iOSMajorVersion,
          self.supportsLiquidGlass ? @"✅" : @"模拟",
          (long)self.displayType,
          self.isLowPowerMode ? @"是" : @"否");
}

- (void)detectDisplayType {
    if (self.deviceModel != YZDeviceModeliPhone) return;
    if (self.displayType != YZDisplayTypeUnknown && self.displayType != YZDisplayTypeClassic) return; // 已检测过

    UIWindow *window = YZEnvironmentCurrentWindow();

    self.displayType = (window.safeAreaInsets.bottom > 0) ? YZDisplayTypeNotch : YZDisplayTypeClassic;
    NSLog(@"[小杳知] 屏幕类型检测完成: %@", self.displayType == YZDisplayTypeNotch ? @"全面屏" : @"非全面屏");
}

- (CGFloat)safeAreaBottomInset {
    UIWindow *window = YZEnvironmentCurrentWindow();
    return window.safeAreaInsets.bottom;
}

- (CGFloat)safeAreaTopInset {
    UIWindow *window = YZEnvironmentCurrentWindow();
    return window.safeAreaInsets.top;
}

- (CGFloat)screenWidth {
    return UIScreen.mainScreen.bounds.size.width;
}

- (CGFloat)screenHeight {
    return UIScreen.mainScreen.bounds.size.height;
}

- (CGFloat)sheetCornerRadius {
    switch (self.displayType) {
        case YZDisplayTypeNotch:
            return 32.0;
        case YZDisplayTypeClassic:
            return 24.0;
        case YZDisplayTypeiPad:
            return 36.0;
        default:
            return 28.0;
    }
}

@end
