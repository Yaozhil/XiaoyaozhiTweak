#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, YZDeviceModel) {
    YZDeviceModelUnknown,
    YZDeviceModeliPhone,
    YZDeviceModeliPad
};

typedef NS_ENUM(NSInteger, YZDisplayType) {
    YZDisplayTypeUnknown,
    YZDisplayTypeNotch,     // 全面屏 (iPhone X+)
    YZDisplayTypeClassic,   // 非全面屏 (iPhone 8 及以下)
    YZDisplayTypeiPad
};

@interface YZEnvironmentDetector : NSObject

+ (instancetype)shared;

/// iOS 主版本号 (14-26)
@property (nonatomic, readonly) NSInteger iOSMajorVersion;

/// 设备型号
@property (nonatomic, readonly) YZDeviceModel deviceModel;

/// 屏幕类型（是否全面屏）
@property (nonatomic, readonly) YZDisplayType displayType;

/// 是否支持 iOS 26 Liquid Glass 原生 API
@property (nonatomic, readonly) BOOL supportsLiquidGlass;

/// 是否处于低功耗模式
@property (nonatomic, readonly) BOOL isLowPowerMode;

/// 安全区域底部高度
@property (nonatomic, readonly) CGFloat safeAreaBottomInset;

/// 安全区域顶部高度
@property (nonatomic, readonly) CGFloat safeAreaTopInset;

/// 屏幕宽度
@property (nonatomic, readonly) CGFloat screenWidth;

/// 屏幕高度
@property (nonatomic, readonly) CGFloat screenHeight;

/// 面板推荐圆角半径
@property (nonatomic, readonly) CGFloat sheetCornerRadius;

@end
