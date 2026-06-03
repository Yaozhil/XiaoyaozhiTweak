#import "YZGlassOverlayView.h"
#import "YZEnvironmentDetector.h"
#import "YZConfigManager.h"

@interface YZGlassOverlayView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *refractionLayer;
@end

@implementation YZGlassOverlayView

#pragma mark - Lifecycle

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

+ (instancetype)glassOverlayWithFrame:(CGRect)frame {
    return [[YZGlassOverlayView alloc] initWithFrame:frame];
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;

    YZConfigManager *config = [YZConfigManager shared];
    self.glassEffectEnabled = [config boolForKey:@"glass_effect_enabled"];
    self.vibrancy = 0.3;
    self.refraction = 0.15;
    self.glassTintColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.borderWidth = 0.5;
    self.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    self.glassCornerRadius = [YZEnvironmentDetector shared].sheetCornerRadius;

    [self buildGlassLayers];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blurView.frame = self.bounds;
    self.refractionLayer.frame = self.bounds;
    self.layer.cornerRadius = self.glassCornerRadius;
}

- (void)dealloc {
    [self.blurView removeFromSuperview];
}

#pragma mark - Glass Effect

- (void)buildGlassLayers {
    // 移除旧的层次
    [self.blurView removeFromSuperview];
    [self.refractionLayer removeFromSuperlayer];

    YZEnvironmentDetector *env = [YZEnvironmentDetector shared];

    if (env.supportsLiquidGlass && self.glassEffectEnabled) {
        [self applyNativeLiquidGlass];
    } else {
        [self applySimulatedLiquidGlass];
    }

    // 边框
    self.layer.borderWidth = self.borderWidth;
    self.layer.borderColor = self.borderColor.CGColor;
}

- (void)applyNativeLiquidGlass {
    // iOS 26 Liquid Glass 原生实现
    // 使用新版 UIGlassEffect（如果 API 可用）
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = self.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // 添加微妙的渐变叠加模拟折射
    self.refractionLayer = [CAGradientLayer layer];
    self.refractionLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor
    ];
    self.refractionLayer.locations = @[@0.0, @0.5, @1.0];
    self.refractionLayer.startPoint = CGPointMake(0.15, 0.0);
    self.refractionLayer.endPoint = CGPointMake(0.85, 1.0);

    [self insertSubview:self.blurView atIndex:0];
    [self.layer insertSublayer:self.refractionLayer atIndex:0];
}

- (void)applySimulatedLiquidGlass {
    // iOS 14-25 模拟液态玻璃
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = self.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.backgroundColor = self.glassTintColor;

    // 模拟折射层
    self.refractionLayer = [CAGradientLayer layer];
    CGFloat alpha = MIN(self.refraction + 0.05, 0.25);
    self.refractionLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:alpha].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:alpha * 0.3].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:alpha * 0.7].CGColor
    ];
    self.refractionLayer.locations = @[@0.0, @0.4, @1.0];
    self.refractionLayer.startPoint = CGPointMake(0.0, 0.0);
    self.refractionLayer.endPoint = CGPointMake(1.0, 1.0);

    [self insertSubview:self.blurView atIndex:0];
    [self.layer insertSublayer:self.refractionLayer atIndex:0];
}

- (void)refreshGlassEffect {
    [self buildGlassLayers];
    [self setNeedsLayout];
}

#pragma mark - Setters

- (void)setGlassEffectEnabled:(BOOL)glassEffectEnabled {
    if (_glassEffectEnabled == glassEffectEnabled) return;
    _glassEffectEnabled = glassEffectEnabled;
    [self refreshGlassEffect];
}

- (void)setVibrancy:(CGFloat)vibrancy {
    _vibrancy = MAX(0.0, MIN(1.0, vibrancy));
    // 更新模糊效果的活性强度（通过 alpha 模拟）
    self.blurView.alpha = 0.6 + (_vibrancy * 0.4);
}

- (void)setGlassCornerRadius:(CGFloat)glassCornerRadius {
    _glassCornerRadius = glassCornerRadius;
    self.layer.cornerRadius = glassCornerRadius;
}

@end
