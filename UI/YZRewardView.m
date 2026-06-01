#import "YZRewardView.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *sCachedRewardURL = nil;

@implementation YZRewardView

+ (void)openRewardPage {
    // 已缓存则直接跳转
    if (sCachedRewardURL.length > 0) {
        [self openURLString:sCachedRewardURL];
        return;
    }

    // 首次加载：异步解码赞赏码
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *url = [self decodeRewardQRCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (url.length > 0) {
                sCachedRewardURL = url;
                [self openURLString:url];
            } else {
                [self showDecodeFailedToast];
            }
        });
    });
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
            return feature.messageString;
        }
    }
    return nil;
}

+ (UIImage *)loadRewardImage {
    NSArray *paths = @[
        @"/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/var/jb/var/mobile/Documents/reward_qr.png",
    ];

    for (NSString *path in paths) {
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        if (img) return img;
    }

    // 尝试从主 bundle 加载
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"reward_qr" ofType:@"png"];
    return [UIImage imageWithContentsOfFile:bundlePath];
}

+ (void)openURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    // 触觉反馈
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showDecodeFailedToast];
            });
        }
    }];
}

+ (void)showDecodeFailedToast {
    // 解码失败时保存图片到相册作为兜底
    UIImage *image = [self loadRewardImage];
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        AudioServicesPlaySystemSound(1104);
    }
}

@end
