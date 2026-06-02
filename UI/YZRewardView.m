#import "YZRewardView.h"
#import <UIKit/UIKit.h>
#import <string.h>

extern UIImage *YZEmbeddedDonationImage(void);

@implementation YZRewardView

+ (void)openRewardPage {
    [self openRewardPageWithFallback:nil];
}

+ (void)openRewardPageWithFallback:(void (^)(void))fallback {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [self loadRewardImage];
        if (!image) {
            [self showToast:@"未找到赞赏码资源"];
            if (fallback) fallback();
            return;
        }

        if ([self scanRewardImageWithWeChat:image]) {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [gen impactOccurred];
        } else {
            [self showToast:@"赞赏页跳转失败，请稍后重试"];
            if (fallback) fallback();
        }
    });
}

+ (UIImage *)loadRewardImage {
    UIImage *embedded = YZEmbeddedDonationImage();
    if (embedded) return embedded;

    NSArray<NSString *> *paths = @[
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/Library/Application Support/XiaoyaozhiTweak/reward_qr.png",
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png",
        @"/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png",
    ];

    for (NSString *path in paths) {
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) return image;
    }
    return nil;
}

+ (id)allocInitClassNamed:(NSString *)className {
    Class cls = NSClassFromString(className);
    if (!cls) return nil;

    @try {
        id object = [[cls alloc] init];
        return object;
    } @catch (NSException *exception) {
        NSLog(@"[小杳知] 初始化 %@ 失败: %@", className, exception);
        return nil;
    }
}

+ (id)invokeSelector:(SEL)selector target:(id)target arguments:(NSArray *)arguments {
    if (!target || ![target respondsToSelector:selector]) return nil;

    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature) return nil;

    NSUInteger expected = signature.numberOfArguments > 2 ? signature.numberOfArguments - 2 : 0;
    if (arguments.count < expected) return nil;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;

    for (NSUInteger i = 0; i < expected; i++) {
        const char *type = [signature getArgumentTypeAtIndex:i + 2];
        id value = [arguments objectAtIndex:i];

        if (type && (strcmp(type, @encode(BOOL)) == 0 || strcmp(type, "B") == 0)) {
            BOOL boolValue = [value boolValue];
            [invocation setArgument:&boolValue atIndex:i + 2];
        } else if (type && (strcmp(type, @encode(int)) == 0 || strcmp(type, @encode(unsigned int)) == 0)) {
            int intValue = [value intValue];
            [invocation setArgument:&intValue atIndex:i + 2];
        } else if (type && (strcmp(type, @encode(NSInteger)) == 0 || strcmp(type, @encode(NSUInteger)) == 0 || strcmp(type, @encode(long long)) == 0 || strcmp(type, @encode(unsigned long long)) == 0)) {
            NSInteger integerValue = [value integerValue];
            [invocation setArgument:&integerValue atIndex:i + 2];
        } else {
            id objectValue = value == (id)kCFNull ? nil : value;
            [invocation setArgument:&objectValue atIndex:i + 2];
        }
    }

    @try {
        [invocation invoke];
        const char *returnType = signature.methodReturnType;
        if (!returnType || returnType[0] == 'v') return nil;

        __unsafe_unretained id result = nil;
        [invocation getReturnValue:&result];
        return result;
    } @catch (NSException *exception) {
        NSLog(@"[小杳知] 调用 %@ 失败: %@", NSStringFromSelector(selector), exception);
        return nil;
    }
}

+ (id)newLogicParams {
    id params = [self allocInitClassNamed:@"ScanQRCodeLogicParams"];
    if (!params) return nil;

    SEL initWithCodeTypeFromScene = NSSelectorFromString(@"initWithCodeType:fromScene:");
    if ([params respondsToSelector:initWithCodeTypeFromScene]) {
        id result = [self invokeSelector:initWithCodeTypeFromScene target:params arguments:@[@27, @2]];
        if (result) return result;
    }

    SEL initWithCodeType = NSSelectorFromString(@"initWithCodeType:");
    if ([params respondsToSelector:initWithCodeType]) {
        id result = [self invokeSelector:initWithCodeType target:params arguments:@[@27]];
        if (result) return result;
    }
    return params;
}

+ (id)newScannerParams {
    id params = [self allocInitClassNamed:@"NewQRCodeScannerParams"];
    if (!params) return nil;

    SEL initWithCodeType = NSSelectorFromString(@"initWithCodeType:");
    if ([params respondsToSelector:initWithCodeType]) {
        id result = [self invokeSelector:initWithCodeType target:params arguments:@[@27]];
        if (result) return result;
    }
    return params;
}

+ (id)scanResultsManager {
    Class mgrClass = NSClassFromString(@"ScanQRCodeResultsMgr");
    if (!mgrClass) return nil;

    Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
    SEL defaultCenter = NSSelectorFromString(@"defaultCenter");
    SEL getService = NSSelectorFromString(@"getService:");
    if ([serviceCenterClass respondsToSelector:defaultCenter]) {
        id center = [self invokeSelector:defaultCenter target:serviceCenterClass arguments:@[]];
        if ([center respondsToSelector:getService]) {
            id service = [self invokeSelector:getService target:center arguments:@[mgrClass]];
            if (service) return service;
        }
    }

    return [self allocInitClassNamed:@"ScanQRCodeResultsMgr"];
}

+ (id)newLogicControllerWithViewController:(UIViewController *)viewController logicParams:(id)logicParams {
    id controller = [self allocInitClassNamed:@"ScanQRCodeLogicController"];
    if (!controller) return nil;

    SEL initSelector = NSSelectorFromString(@"initWithViewController:logicParams:");
    if ([controller respondsToSelector:initSelector]) {
        id result = [self invokeSelector:initSelector target:controller arguments:@[viewController ?: (id)kCFNull, logicParams ?: (id)kCFNull]];
        if (result) return result;
    }
    return controller;
}

+ (id)newScannerWithDelegate:(id)delegate scannerParams:(id)scannerParams {
    id scanner = [self allocInitClassNamed:@"NewQRCodeScanner"];
    if (!scanner) return nil;

    SEL initSelector = NSSelectorFromString(@"initWithDelegate:scannerParams:");
    if ([scanner respondsToSelector:initSelector]) {
        id result = [self invokeSelector:initSelector target:scanner arguments:@[delegate ?: (id)kCFNull, scannerParams ?: (id)kCFNull]];
        if (result) return result;
    }
    return scanner;
}

+ (UIViewController *)topViewController {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) { keyWindow = window; break; }
            }
            if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
            if (keyWindow) break;
        }
    } else {
        id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
        if ([delegate respondsToSelector:@selector(window)]) {
            keyWindow = delegate.window;
        }
    }

    UIViewController *controller = keyWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    while ([controller isKindOfClass:UINavigationController.class]) controller = ((UINavigationController *)controller).topViewController;
    while ([controller isKindOfClass:UITabBarController.class]) controller = ((UITabBarController *)controller).selectedViewController;
    return controller;
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

+ (UIImage *)rewardScanImageFromImage:(UIImage *)image {
    if (!image) return nil;

    CGFloat w = image.size.width;
    CGFloat h = image.size.height;
    CGFloat side = MIN(w, h) * 0.50;
    CGRect rect = CGRectMake((w - side) / 2.0, h * 0.13, side, side);
    UIImage *cropped = [self croppedImage:image rect:rect];
    return cropped ?: image;
}

+ (void)cleanupHiddenImageController:(UIViewController *)imageController {
    if (!imageController.parentViewController) return;

    [imageController willMoveToParentViewController:nil];
    [imageController.view removeFromSuperview];
    [imageController removeFromParentViewController];
}

+ (BOOL)scanRewardImageWithWeChat:(UIImage *)image {
    if (!image) return NO;
    UIImage *scanImage = [self rewardScanImageFromImage:image];

    UIViewController *imageController = [self allocInitClassNamed:@"MsgImgFullScreenViewController"];
    if (![imageController isKindOfClass:UIViewController.class]) {
        imageController = [[UIViewController alloc] init];
    }

    UIViewController *hostController = [self topViewController];
    if (hostController) {
        [hostController addChildViewController:imageController];
        imageController.view.frame = CGRectMake(-4, -4, 2, 2);
        imageController.view.alpha = 0.01;
        imageController.view.userInteractionEnabled = NO;
        [hostController.view addSubview:imageController.view];
        [imageController didMoveToParentViewController:hostController];
    }

    id logicParams = [self newLogicParams];
    id scannerParams = [self newScannerParams];
    id logicController = [self newLogicControllerWithViewController:imageController logicParams:logicParams];
    id resultsManager = [self scanResultsManager];

    SEL setScanLogicController = NSSelectorFromString(@"setScanLogicController:");
    if ([resultsManager respondsToSelector:setScanLogicController] && logicController) {
        [self invokeSelector:setScanLogicController target:resultsManager arguments:@[logicController]];
    }

    id scanner = [self newScannerWithDelegate:(resultsManager ?: logicController) scannerParams:scannerParams];
    if (!scanner) {
        [self cleanupHiddenImageController:imageController];
        return NO;
    }

    SEL scanOnePicture = NSSelectorFromString(@"scanOnePicture:");
    if (![scanner respondsToSelector:scanOnePicture]) {
        [self cleanupHiddenImageController:imageController];
        return NO;
    }

    if ([imageController respondsToSelector:@selector(addChildViewController:)] && [scanner isKindOfClass:UIViewController.class]) {
        [imageController addChildViewController:(UIViewController *)scanner];
        [(UIViewController *)scanner didMoveToParentViewController:imageController];
    }

    [self invokeSelector:scanOnePicture target:scanner arguments:@[scanImage ?: image]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self cleanupHiddenImageController:imageController];
    });

    return YES;
}

+ (void)showToast:(NSString *)msg {
    if (msg.length == 0) return;
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
                }
                if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
                break;
            }
        }
    } else {
        id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
        if ([delegate respondsToSelector:@selector(window)]) {
            keyWindow = delegate.window;
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

    CGSize size = [msg boundingRectWithSize:CGSizeMake(260, 60)
                                    options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: toast.font}
                                    context:nil].size;
    CGFloat width = MIN(ceil(size.width) + 36, 280);
    toast.frame = CGRectMake((keyWindow.bounds.size.width - width) / 2.0,
                             keyWindow.bounds.size.height - 140,
                             width,
                             ceil(size.height) + 20);
    [keyWindow addSubview:toast];

    [UIView animateWithDuration:0.22 animations:^{
        toast.alpha = 1;
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.22 delay:1.8 options:UIViewAnimationOptionCurveEaseIn animations:^{
            toast.alpha = 0;
        } completion:^(__unused BOOL finished2) {
            [toast removeFromSuperview];
        }];
    }];
}

@end
