#import <UIKit/UIKit.h>

// 投喂 - 解码赞赏码并直接跳转微信打赏页
@interface YZRewardView : NSObject

+ (void)openRewardPage;
+ (void)openRewardPageWithFallback:(void (^)(void))fallback;
+ (BOOL)isRewardScanInProgress;

@end
