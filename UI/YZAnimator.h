#import <UIKit/UIKit.h>

// 液态动画引擎 - iOS 26 弹性弹簧动画
@interface YZAnimator : NSObject

/// 液态弹性弹簧动画
+ (void)animateSpringWithDuration:(NSTimeInterval)duration
                            delay:(NSTimeInterval)delay
                     dampingRatio:(CGFloat)damping
                   initialVelocity:(CGVector)velocity
                           options:(UIViewAnimationOptions)options
                        animations:(void(^)(void))animations
                        completion:(void(^)(BOOL finished))completion;

/// 面板展示动画（预设参数）
+ (void)animateSheetPresentation:(void(^)(void))animations;

/// 面板消失动画（预设参数）
+ (void)animateSheetDismissal:(void(^)(void))animations completion:(void(^)(BOOL))completion;

/// 淡入动画
+ (void)animateFadeIn:(UIView *)view duration:(NSTimeInterval)duration;

/// 淡出动画
+ (void)animateFadeOut:(UIView *)view duration:(NSTimeInterval)duration completion:(void(^)(BOOL))completion;

/// 淡入加位移动画（用于内容展示）
+ (void)animateContentAppear:(UIView *)view delay:(NSTimeInterval)delay;

@end
