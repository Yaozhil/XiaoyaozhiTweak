#import <UIKit/UIKit.h>

// 粒子动效组件 - 实现液态交互中的微粒子效果
@interface YZParticleEffectView : UIView

/// 粒子颜色
@property (nonatomic, strong) UIColor *particleColor;

/// 粒子数量（默认 8）
@property (nonatomic, assign) NSInteger particleCount;

/// 粒子大小范围 (min, max)，默认 (2, 6)
@property (nonatomic, assign) CGSize particleSizeRange;

/// 粒子寿命 (秒)，默认 2.5
@property (nonatomic, assign) CGFloat particleLifetime;

/// 发射速率（每秒），默认 3
@property (nonatomic, assign) CGFloat emissionRate;

/// 扩散半径，默认 30
@property (nonatomic, assign) CGFloat spreadRadius;

/// 开始粒子动画
- (void)startEmitting;

/// 停止发射（已有粒子继续消散）
- (void)stopEmitting;

/// 立即清除所有粒子
- (void)clearAllParticles;

/// 在指定位置爆发粒子
- (void)burstAtPoint:(CGPoint)point;

@end
