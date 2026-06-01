#import <UIKit/UIKit.h>

// 液态玻璃叠加层 - 提供 iOS 26 Liquid Glass 效果
@interface YZGlassOverlayView : UIView

/// 是否启用液态玻璃效果（iOS 26 原生 / 14-25 模拟）
@property (nonatomic, assign) BOOL glassEffectEnabled;

/// 模糊强度 (0.0 - 1.0)，默认 0.3
@property (nonatomic, assign) CGFloat vibrancy;

/// 折射模拟强度 (0.0 - 1.0)，默认 0.15
@property (nonatomic, assign) CGFloat refraction;

/// 玻璃色调
@property (nonatomic, strong) UIColor *glassTintColor;

/// 边框宽度
@property (nonatomic, assign) CGFloat borderWidth;

/// 边框颜色（半透明白色）
@property (nonatomic, strong) UIColor *borderColor;

/// 圆角半径
@property (nonatomic, assign) CGFloat glassCornerRadius;

/// 快捷构造方法
+ (instancetype)glassOverlayWithFrame:(CGRect)frame;

/// 刷新玻璃效果（配置变更后调用）
- (void)refreshGlassEffect;

@end
