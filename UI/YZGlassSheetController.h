#import <UIKit/UIKit.h>

// 小杳知主菜单控制器 - iOS 设置风格 + 液态玻璃质感
@interface YZGlassSheetController : UIViewController

/// 自定义头像（nil 则自动获取微信头像）
@property (nonatomic, strong) UIImage *appIcon;

/// 刷新头像
- (void)refreshAvatar;

/// 刷新关注状态
- (void)refreshFollowStatus;

/// 展示（添加到 window）
- (void)presentInWindow:(UIWindow *)window;
- (void)presentFromTopViewController;

/// 关闭
- (void)dismissAnimated;
- (void)dismissAnimatedWithCompletion:(void(^)(void))completion;

@property (nonatomic, readonly) BOOL isPresented;

@end
