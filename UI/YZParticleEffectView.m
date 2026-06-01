#import "YZParticleEffectView.h"
#import "YZConfigManager.h"

@interface YZParticleEffectView ()
@property (nonatomic, strong) CAEmitterLayer *emitterLayer;
@property (nonatomic, strong) CAEmitterCell *particleCell;
@property (nonatomic, assign) BOOL isEmitting;
@end

@implementation YZParticleEffectView

+ (Class)layerClass {
    return [CAEmitterLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;

    self.particleColor = [UIColor colorWithRed:0.40 green:0.65 blue:0.85 alpha:0.7];
    self.particleCount = 8;
    self.particleSizeRange = CGSizeMake(2, 6);
    self.particleLifetime = 2.5;
    self.emissionRate = 3;
    self.spreadRadius = 30;

    [self setupEmitter];
}

- (void)setupEmitter {
    self.emitterLayer = (CAEmitterLayer *)self.layer;
    self.emitterLayer.emitterShape = kCAEmitterLayerCircle;
    self.emitterLayer.emitterMode = kCAEmitterLayerOutline;
    self.emitterLayer.renderMode = kCAEmitterLayerAdditive;
    self.emitterLayer.seed = arc4random();

    self.particleCell = [CAEmitterCell emitterCell];
    self.particleCell.contents = (id)[self particleImage].CGImage;
    self.particleCell.birthRate = 0; // 默认暂停
    self.particleCell.lifetime = self.particleLifetime;
    self.particleCell.lifetimeRange = 0.5;
    self.particleCell.color = self.particleColor.CGColor;
    self.particleCell.alphaSpeed = -0.4;
    self.particleCell.velocity = 20;
    self.particleCell.velocityRange = 15;
    self.particleCell.emissionRange = M_PI * 2;
    self.particleCell.scale = 0.5;
    self.particleCell.scaleRange = 0.3;
    self.particleCell.scaleSpeed = -0.1;

    self.emitterLayer.emitterCells = @[self.particleCell];
}

- (UIImage *)particleImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 8), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextAddArc(ctx, 4, 4, 4, 0, M_PI * 2, YES);
    CGContextFillPath(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)startEmitting {
    if (self.isEmitting) return;
    if (![YZConfigManager.shared boolForKey:@"particle_effect_enabled"]) return;

    self.isEmitting = YES;
    self.particleCell.birthRate = self.emissionRate;
}

- (void)stopEmitting {
    self.isEmitting = NO;
    self.particleCell.birthRate = 0;
}

- (void)clearAllParticles {
    [self stopEmitting];
    // 快速消散现存粒子，不操作 backing layer
    self.particleCell.birthRate = 0;
    self.particleCell.lifetime = 0.01;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.particleCell.lifetime = self.particleLifetime;
        if (self.isEmitting) self.particleCell.birthRate = self.emissionRate;
    });
}

- (void)burstAtPoint:(CGPoint)point {
    self.emitterLayer.emitterPosition = point;
    self.particleCell.birthRate = self.emissionRate * 4;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.particleCell.birthRate = self.isEmitting ? self.emissionRate : 0;
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.isEmitting) {
        self.emitterLayer.emitterPosition = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        self.emitterLayer.emitterSize = CGSizeMake(self.spreadRadius, self.spreadRadius);
    }
}

#pragma mark - Setters

- (void)setParticleColor:(UIColor *)particleColor {
    _particleColor = particleColor;
    self.particleCell.color = particleColor.CGColor;
}

- (void)setParticleLifetime:(CGFloat)particleLifetime {
    _particleLifetime = particleLifetime;
    self.particleCell.lifetime = particleLifetime;
}

@end
