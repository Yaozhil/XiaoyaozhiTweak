#import "YZFluidButton.h"
#import "YZGlassOverlayView.h"
#import "YZAnimator.h"
#import "YZConfigManager.h"

@interface YZFluidButton ()
@property (nonatomic, strong) UIImageView *symbolImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) YZGlassOverlayView *glassBackground;
@property (nonatomic, assign) BOOL isPressed;
@end

@implementation YZFluidButton

#pragma mark - Lifecycle

+ (instancetype)buttonWithTitle:(NSString *)title symbolName:(NSString *)symbolName {
    YZFluidButton *button = [[YZFluidButton alloc] initWithFrame:CGRectZero];
    button.title = title;
    button.symbolName = symbolName;
    return button;
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
    self.glassStyle = YES;
    self.hapticStyle = UIImpactFeedbackStyleLight;
    self.tintColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.62 alpha:1.0];

    // 液态玻璃背景
    self.glassBackground = [[YZGlassOverlayView alloc] initWithFrame:self.bounds];
    self.glassBackground.userInteractionEnabled = NO;
    self.glassBackground.glassCornerRadius = 16.0;
    [self addSubview:self.glassBackground];

    // SF Symbol 图标
    self.symbolImageView = [[UIImageView alloc] init];
    self.symbolImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.symbolImageView.tintColor = self.tintColor;
    [self addSubview:self.symbolImageView];

    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.titleLabel.textColor = self.tintColor;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 1;
    [self addSubview:self.titleLabel];

    // 触摸事件
    [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    self.glassBackground.frame = self.bounds;

    CGFloat iconSize = MIN(w * 0.35, 28.0);
    self.symbolImageView.frame = CGRectMake((w - iconSize) / 2.0, h * 0.15, iconSize, iconSize);

    CGFloat labelY = CGRectGetMaxY(self.symbolImageView.frame) + 6.0;
    self.titleLabel.frame = CGRectMake(4, labelY, w - 8, h - labelY - 4);
}

#pragma mark - Properties

- (void)setTitle:(NSString *)title {
    _title = [title copy];
    self.titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setSymbolName:(NSString *)symbolName {
    _symbolName = [symbolName copy];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        self.symbolImageView.image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    }
    [self setNeedsLayout];
}

- (void)setTintColor:(UIColor *)tintColor {
    _tintColor = tintColor;
    self.symbolImageView.tintColor = tintColor;
    self.titleLabel.textColor = tintColor;
}

- (void)setGlassStyle:(BOOL)glassStyle {
    _glassStyle = glassStyle;
    self.glassBackground.glassEffectEnabled = glassStyle;
    if (!glassStyle) {
        self.glassBackground.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    }
}

#pragma mark - Touch Handling

- (void)handleTouchDown {
    self.isPressed = YES;
    [self playPressAnimation];

    // 触觉反馈
    if ([YZConfigManager.shared boolForKey:@"haptic_feedback_enabled"]) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:self.hapticStyle];
        [generator impactOccurred];
    }
}

- (void)handleTouchUp {
    self.isPressed = NO;
    [self playReleaseAnimation];
}

- (void)playPressAnimation {
    [YZAnimator animateSpringWithDuration:0.35
                                    delay:0
                             dampingRatio:0.55
                           initialVelocity:CGVectorMake(0, 0)
                                   options:UIViewAnimationOptionCurveEaseIn
                                animations:^{
        self.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self.alpha = 0.85;
    } completion:nil];
}

- (void)playReleaseAnimation {
    [YZAnimator animateSpringWithDuration:0.45
                                    delay:0
                             dampingRatio:0.55
                           initialVelocity:CGVectorMake(0, 0.6)
                                   options:UIViewAnimationOptionCurveEaseOut
                                animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end
