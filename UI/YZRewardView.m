#import "YZRewardView.h"
#import <objc/message.h>
#import <UIKit/UIKit.h>

static NSString *sCachedRewardURL = nil;

@implementation YZRewardView

+ (void)openRewardPage {
    if (sCachedRewardURL.length > 0) {
        [self openRewardURL:sCachedRewardURL];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = [self decodeRewardQRCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url.length > 0) {
                sCachedRewardURL = url;
                [self openRewardURL:url];
            } else {
                [self showToast:@"赞赏码未识别，请尝试长按保存"];
            }
        });
    });
}

+ (UIImage *)loadRewardImage {
    NSArray *paths = @[
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
    ];
    for (NSString *path in paths) {
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        if (img) {
            NSLog(@"[小杳知] 赞赏码加载: %@", path);
            return img;
        }
    }
    NSLog(@"[小杳知] 赞赏码未找到，检查路径: %@", paths);
    return nil;
}

+ (NSString *)decodeRewardQRCode {
    UIImage *image = [self loadRewardImage];
    if (!image) return nil;

    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) return nil;

    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                              context:nil
                                              options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    NSArray<CIQRCodeFeature *> *features = (NSArray<CIQRCodeFeature *> *)[detector featuresInImage:ciImage];
    for (CIQRCodeFeature *feature in features) {
        if (feature.messageString.length > 0) {
            NSLog(@"[小杳知] 解码成功: %@", feature.messageString);
            return feature.messageString;
        }
    }
    return nil;
}

+ (void)openRewardURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    // 在微信进程内，openURL 会被微信的 URL handler 拦截处理
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [self showToast:@"跳转失败，请长按保存赞赏码后扫码"];
            }
        });
    }];
}

+ (void)showToast:(NSString *)msg {
    if (msg.length == 0) return;
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
            if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
            break;
        }
    }
    if (!keyWindow) return;

    UILabel *toast = [[UILabel alloc] init];
    toast.text = msg;
    toast.font = [UIFont systemFontOfSize:13];
    toast.textColor = UIColor.whiteColor;
    toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    toast.alpha = 0;

    CGSize s = [msg boundingRectWithSize:CGSizeMake(260, 60) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: toast.font} context:nil].size;
    toast.frame = CGRectMake((keyWindow.bounds.size.width - MIN(ceil(s.width) + 36, 280)) / 2.0,
                             keyWindow.bounds.size.height - 140,
                             MIN(ceil(s.width) + 36, 280), ceil(s.height) + 20);
    [keyWindow addSubview:toast];

    [UIView animateWithDuration:0.22 animations:^{ toast.alpha = 1; } completion:^(BOOL d) {
        [UIView animateWithDuration:0.22 delay:1.8 options:UIViewAnimationOptionCurveEaseIn animations:^{ toast.alpha = 0; } completion:^(BOOL d2) { [toast removeFromSuperview]; }];
    }];
}

@end
