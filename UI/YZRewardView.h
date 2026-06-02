#import <UIKit/UIKit.h>

// 投喂 - 通过微信扫码结果链路直接跳转真实赞赏页
@interface YZRewardView : NSObject

+ (void)openRewardPage;
+ (void)openRewardPageFromViewController:(UIViewController *)viewController;
+ (void)openRewardPageWithFallback:(void (^)(void))fallback;
+ (void)openRewardPageFromViewController:(UIViewController *)viewController fallback:(void (^)(void))fallback;

@end
