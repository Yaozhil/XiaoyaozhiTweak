#import "YZRewardView.h"
#import <objc/message.h>
#import <UIKit/UIKit.h>

static NSString *sCachedRewardURL = nil;

@implementation YZRewardView

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
    return nil;
}

+ (NSString *)decodeRewardQRCode {
    UIImage *image = [self loadRewardImage];
    if (!image) {
        NSLog(@"[小杳知] 赞赏码图片未找到");
        return nil;
    }
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) {
        NSLog(@"[小杳知] CIImage 创建失败");
        return nil;
    }
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                              context:nil
                                              options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    NSArray<CIQRCodeFeature *> *features = (NSArray<CIQRCodeFeature *> *)[detector featuresInImage:ciImage];
    for (CIQRCodeFeature *feature in features) {
        if (feature.messageString.length > 0) {
            NSLog(@"[小杳知] 赞赏码解码成功: %@", feature.messageString);
            return feature.messageString;
        }
    }
    NSLog(@"[小杳知] 赞赏码解码: 未找到 QR 内容");
    return nil;
}

+ (UIViewController *)topMostViewController {
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
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    return root;
}

+ (void)handleRewardURL:(NSString *)urlString {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    // 方案1: 微信内部 URL 路由
    Class handlerClass = NSClassFromString(@"MMURLHandler");
    if (handlerClass) {
        id handler = nil;
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if ([handlerClass respondsToSelector:sharedSel]) {
            handler = ((id (*)(id, SEL))objc_msgSend)(handlerClass, sharedSel);
        }
        if (!handler) {
            handler = ((id (*)(id, SEL))objc_msgSend)([handlerClass alloc], @selector(init));
        }
        SEL handleSel = NSSelectorFromString(@"handleURL:");
        if ([handler respondsToSelector:handleSel]) {
            ((void (*)(id, SEL, id))objc_msgSend)(handler, handleSel, url);
            return;
        }
    }

    // 方案2: 微信内部 WebView push 到导航栈
    Class webVCClass = NSClassFromString(@"MMWebViewController");
    if (!webVCClass) webVCClass = NSClassFromString(@"WCWebViewController");
    if (webVCClass) {
        id webVC = ((id (*)(id, SEL))objc_msgSend)([webVCClass alloc], @selector(init));
        if (webVC) {
            SEL loadSel = NSSelectorFromString(@"loadRequest:");
            if (![webVC respondsToSelector:loadSel]) loadSel = NSSelectorFromString(@"loadURLString:");
            if ([webVC respondsToSelector:loadSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(webVC, loadSel, urlString);
            }
            UIViewController *topVC = [self topMostViewController];
            if (topVC && topVC.navigationController) {
                [topVC.navigationController pushViewController:webVC animated:YES];
                return;
            }
        }
    }

    // 方案3: 兜底 openURL
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

+ (void)openRewardPage {
    if (sCachedRewardURL.length > 0) {
        [self handleRewardURL:sCachedRewardURL];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = [self decodeRewardQRCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url.length > 0) {
                sCachedRewardURL = url;
                [self handleRewardURL:url];
            }
        });
    });
}

@end
