#import <UIKit/UIKit.h>

// 投喂 - 通过微信扫码结果链路直接跳转真实赞赏页
@interface YZRewardView : NSObject

+ (void)openRewardPage;
+ (void)openRewardPageWithFallback:(void (^)(void))fallback;

@end
