#import "YZRewardView.h"
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

extern UIImage *YZEmbeddedDonationImage(void);

static NSString *sCachedRewardURL = nil;

@implementation YZRewardView

+ (void)openRewardPage {
    [self openRewardPageWithFallback:nil];
}

+ (void)openRewardPageWithFallback:(void (^)(void))fallback {
    if (sCachedRewardURL.length > 0) {
        [self openRewardURL:sCachedRewardURL fallback:fallback];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = [self decodeRewardQRCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url.length > 0) {
                sCachedRewardURL = url;
                [self openRewardURL:url fallback:fallback];
            } else {
                [self showToast:@"赞赏码未识别，请尝试长按保存"];
                if (fallback) fallback();
            }
        });
    });
}

+ (UIImage *)loadRewardImage {
    UIImage *embedded = YZEmbeddedDonationImage();
    if (embedded) return embedded;

    NSArray *paths = @[
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png",
        @"/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png",
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

+ (NSString *)decodeQRCodeFromImage:(UIImage *)image {
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

+ (UIImage *)croppedImage:(UIImage *)image rect:(CGRect)rect {
    CGImageRef source = image.CGImage;
    if (!source) return nil;

    CGFloat scale = image.scale > 0 ? image.scale : 1.0;
    CGRect pixelRect = CGRectMake(rect.origin.x * scale,
                                  rect.origin.y * scale,
                                  rect.size.width * scale,
                                  rect.size.height * scale);
    pixelRect = CGRectIntersection(pixelRect, CGRectMake(0, 0, CGImageGetWidth(source), CGImageGetHeight(source)));
    if (CGRectIsEmpty(pixelRect)) return nil;

    CGImageRef cropped = CGImageCreateWithImageInRect(source, pixelRect);
    if (!cropped) return nil;

    UIImage *result = [UIImage imageWithCGImage:cropped scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cropped);
    return result;
}

+ (NSArray<UIImage *> *)rewardDecodeCandidatesFromImage:(UIImage *)image {
    if (!image) return @[];

    NSMutableArray<UIImage *> *candidates = [NSMutableArray arrayWithObject:image];
    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    CGFloat shortSide = MIN(w, h);

    NSArray<NSValue *> *rects = @[
        [NSValue valueWithCGRect:CGRectMake(w * 0.22, h * 0.12, shortSide * 0.58, shortSide * 0.58)],
        [NSValue valueWithCGRect:CGRectMake(w * 0.18, h * 0.10, shortSide * 0.66, shortSide * 0.66)],
        [NSValue valueWithCGRect:CGRectMake(w * 0.24, h * 0.16, shortSide * 0.52, shortSide * 0.52)],
        [NSValue valueWithCGRect:CGRectMake(0, 0, w, h * 0.68)]
    ];

    for (NSValue *value in rects) {
        UIImage *cropped = [self croppedImage:image rect:value.CGRectValue];
        if (cropped) [candidates addObject:cropped];
    }
    return candidates;
}

+ (NSString *)decodeRewardQRCode {
    UIImage *image = [self loadRewardImage];
    for (UIImage *candidate in [self rewardDecodeCandidatesFromImage:image]) {
        NSString *url = [self decodeQRCodeFromImage:candidate];
        if (url.length > 0) return url;
    }
    return nil;
}

+ (BOOL)invokeQRCodeLandingOnTarget:(id)target urlString:(NSString *)urlString {
    if (!target || urlString.length == 0) return NO;
    SEL selector = NSSelectorFromString(@"openQRCodeOrWXCodeLandingPage:isShowMultiCodes:businessScene:");
    if (![target respondsToSelector:selector]) return NO;

    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments < 5) return NO;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    NSString *landingURL = urlString;
    BOOL showMultiCodes = NO;
    NSInteger businessScene = 0;
    [invocation setArgument:&landingURL atIndex:2];
    [invocation setArgument:&showMultiCodes atIndex:3];
    [invocation setArgument:&businessScene atIndex:4];
    @try {
        [invocation invoke];
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[小杳知] 赞赏码内部跳转失败: %@", exception);
        return NO;
    }
}

+ (BOOL)openQRCodeLandingIfPossible:(NSString *)urlString {
    Class scannerClass = NSClassFromString(@"ScanQRCodeLogicController");
    if ([self invokeQRCodeLandingOnTarget:scannerClass urlString:urlString]) return YES;

    id scanner = nil;
    @try {
        scanner = [[scannerClass alloc] init];
    } @catch (__unused NSException *exception) {
        scanner = nil;
    }
    return [self invokeQRCodeLandingOnTarget:scanner urlString:urlString];
}

+ (void)openRewardURL:(NSString *)urlString fallback:(void (^)(void))fallback {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (fallback) fallback();
        return;
    }

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    if ([self openQRCodeLandingIfPossible:urlString]) {
        return;
    }

    // 在微信进程内，openURL 会被微信的 URL handler 拦截处理
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [self showToast:@"跳转失败，请长按保存赞赏码后扫码"];
                if (fallback) fallback();
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
