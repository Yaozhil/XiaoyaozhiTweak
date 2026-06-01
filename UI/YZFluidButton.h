#import <UIKit/UIKit.h>

// 液态按钮 - iOS 26 Liquid Glass 风格交互按钮
@interface YZFluidButton : UIControl

/// 按钮标题
@property (nonatomic, copy) NSString *title;

/// SF Symbol 图标名称
@property (nonatomic, copy) NSString *symbolName;

/// 按钮色调
@property (nonatomic, strong) UIColor *tintColor;

/// 液态按钮样式
@property (nonatomic, assign) BOOL glassStyle; // 液态玻璃填充

/// 触觉反馈类型
@property (nonatomic, assign) UIImpactFeedbackStyle hapticStyle;

/// 构造方法
+ (instancetype)buttonWithTitle:(NSString *)title symbolName:(NSString *)symbolName;

/// 按压动画（手动触发）
- (void)playPressAnimation;
- (void)playReleaseAnimation;

@end
