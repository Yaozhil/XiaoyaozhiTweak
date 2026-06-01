#import "YZRewardView.h"
#import <objc/message.h>

static NSString *sCachedRewardURL = nil;

@implementation YZRewardView

+ (void)openRewardPage {
    if (sCachedRewardURL.length > 0) {
        [self openURLString:sCachedRewardURL];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = [self decodeRewardQRCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url.length > 0) {
                sCachedRewardURL = url;
                [self openURLString:url];
            }
        });
    });
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

+ (void)openURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    // 方案1: 系统 openURL（微信进程内会被微信拦截处理）
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            // 方案2: 尝试微信内部 URL handler
            [self openViaWeChatHandler:urlString];
        }
    }];
}

+ (void)openViaWeChatHandler:(NSString *)urlString {
    Class handlerClass = NSClassFromString(@"MMURLHandler");
    if (!handlerClass) return;

    id handler = nil;
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if ([handlerClass respondsToSelector:sharedSel]) {
        handler = ((id (*)(id, SEL))objc_msgSend)(handlerClass, sharedSel);
    }
    if (!handler) {
        handler = ((id (*)(id, SEL))objc_msgSend)(handlerClass, @selector(alloc));
        handler = ((id (*)(id, SEL))objc_msgSend)(handler, @selector(init));
    }

    SEL handleURLSel = NSSelectorFromString(@"handleURL:");
    if ([handler respondsToSelector:handleURLSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(handler, handleURLSel, [NSURL URLWithString:urlString]);
    }
}

@end
