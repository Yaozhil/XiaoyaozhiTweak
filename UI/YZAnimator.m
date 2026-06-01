#import "YZAnimator.h"
#import "YZConfigManager.h"

@implementation YZAnimator

+ (void)animateSpringWithDuration:(NSTimeInterval)duration
                            delay:(NSTimeInterval)delay
                     dampingRatio:(CGFloat)damping
                   initialVelocity:(CGVector)velocity
                           options:(UIViewAnimationOptions)options
                        animations:(void(^)(void))animations
                        completion:(void(^)(BOOL))completion {

    CGFloat initialSpringVelocity = (velocity.dx != 0 || velocity.dy != 0) ? 1.0 : 0.0;

    [UIView animateWithDuration:duration
                          delay:delay
         usingSpringWithDamping:damping
          initialSpringVelocity:initialSpringVelocity
                        options:options
                     animations:animations
                     completion:completion];
}

+ (void)animateSheetPresentation:(void(^)(void))animations {
    YZConfigManager *config = [YZConfigManager shared];
    CGFloat duration = [config floatForKey:@"sheet_animation_duration"];
    CGFloat damping = [config floatForKey:@"sheet_damping_ratio"];

    [self animateSpringWithDuration:duration > 0 ? duration : 0.55
                              delay:0
                       dampingRatio:damping > 0 ? damping : 0.65
                     initialVelocity:CGVectorMake(0, 0.8)
                             options:UIViewAnimationOptionCurveEaseOut
                          animations:animations
                          completion:nil];
}

+ (void)animateSheetDismissal:(void(^)(void))animations completion:(void(^)(BOOL))completion {
    YZConfigManager *config = [YZConfigManager shared];
    CGFloat duration = [config floatForKey:@"sheet_animation_duration"] * 0.8;

    [self animateSpringWithDuration:duration > 0 ? duration : 0.4
                              delay:0
                       dampingRatio:0.8
                     initialVelocity:CGVectorMake(0, 0)
                             options:UIViewAnimationOptionCurveEaseIn
                          animations:animations
                          completion:completion];
}

+ (void)animateFadeIn:(UIView *)view duration:(NSTimeInterval)duration {
    if (view.alpha >= 0.99) return; // 已可见，不重复动画
    view.alpha = 0;
    [UIView animateWithDuration:duration animations:^{ view.alpha = 1.0; }];
}

+ (void)animateFadeOut:(UIView *)view duration:(NSTimeInterval)duration completion:(void(^)(BOOL))completion {
    if (view.alpha <= 0.01) { if (completion) completion(YES); return; }
    [UIView animateWithDuration:duration animations:^{ view.alpha = 0; } completion:completion];
}

+ (void)animateContentAppear:(UIView *)view delay:(NSTimeInterval)delay {
    if (view.alpha >= 0.99 && CGAffineTransformIsIdentity(view.transform)) return;
    view.alpha = 0;
    view.transform = CGAffineTransformMakeTranslation(0, 20);
    [self animateSpringWithDuration:0.45 delay:delay dampingRatio:0.7 initialVelocity:CGVectorMake(0, 0)
                             options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 1.0; view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
