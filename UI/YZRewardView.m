#import "YZRewardView.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <string.h>

extern UIImage *YZEmbeddedDonationImage(void);

@implementation YZRewardView

+ (NSMutableArray *)activeScanObjects {
    static NSMutableArray *objects = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        objects = [NSMutableArray array];
    });
    return objects;
}

+ (void)openRewardPage {
    [self openRewardPageFromViewController:nil fallback:nil];
}

+ (void)openRewardPageFromViewController:(UIViewController *)viewController {
    [self openRewardPageFromViewController:viewController fallback:nil];
}

+ (void)openRewardPageWithFallback:(void (^)(void))fallback {
    [self openRewardPageFromViewController:nil fallback:fallback];
}

+ (void)openRewardPageFromViewController:(UIViewController *)viewController fallback:(void (^)(void))fallback {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self loadRewardImage];
        if (!image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"未找到赞赏码资源"];
                if (fallback) fallback();
            });
            return;
        }

        BOOL success = [self scanRewardImage:image withWeChatFromViewController:viewController];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [gen impactOccurred];
            } else {
                [self showToast:@"赞赏页跳转失败，请稍后重试"];
                if (fallback) fallback();
            }
        });
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

+ (id)allocClassNamed:(NSString *)className {
    Class cls = NSClassFromString(className);
    if (!cls) return nil;

    @try {
        return [cls alloc];
    } @catch (NSException *exception) {
        NSLog(@"[Xiaoyaozhi] alloc %@ failed: %@", className, exception);
        return nil;
    }
}

+ (id)newObjectNamed:(NSString *)className {
    id object = [self allocClassNamed:className];
    if (!object) return nil;

    @try {
        return [object init];
    } @catch (NSException *exception) {
        NSLog(@"[Xiaoyaozhi] init %@ failed: %@", className, exception);
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
        } else if (type && (strcmp(type, @encode(NSInteger)) == 0 || strcmp(type, @encode(NSUInteger)) == 0 ||
                            strcmp(type, @encode(long long)) == 0 || strcmp(type, @encode(unsigned long long)) == 0)) {
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
        NSLog(@"[Xiaoyaozhi] call %@ failed: %@", NSStringFromSelector(selector), exception);
        return nil;
    }
}

+ (id)newLogicParams {
    SEL initWithCodeTypeFromScene = NSSelectorFromString(@"initWithCodeType:fromScene:");
    id params = [self allocClassNamed:@"ScanQRCodeLogicParams"];
    if ([params respondsToSelector:initWithCodeTypeFromScene]) {
        id result = [self invokeSelector:initWithCodeTypeFromScene target:params arguments:@[@27, @2]];
        if (result) return result;
    }

    SEL initWithCodeType = NSSelectorFromString(@"initWithCodeType:");
    params = [self allocClassNamed:@"ScanQRCodeLogicParams"];
    if ([params respondsToSelector:initWithCodeType]) {
        id result = [self invokeSelector:initWithCodeType target:params arguments:@[@27]];
        if (result) return result;
    }

    return [self newObjectNamed:@"ScanQRCodeLogicParams"];
}

+ (id)newScannerParams {
    SEL initWithCodeType = NSSelectorFromString(@"initWithCodeType:");
    id params = [self allocClassNamed:@"NewQRCodeScannerParams"];
    if ([params respondsToSelector:initWithCodeType]) {
        id result = [self invokeSelector:initWithCodeType target:params arguments:@[@27]];
        if (result) return result;
    }

    return [self newObjectNamed:@"NewQRCodeScannerParams"];
}

+ (id)scanResultsManager {
    Class mgrClass = NSClassFromString(@"ScanQRCodeResultsMgr");
    Class contextClass = NSClassFromString(@"MMContext");
    SEL activeUserContext = NSSelectorFromString(@"activeUserContext");
    SEL serviceCenter = NSSelectorFromString(@"serviceCenter");
    SEL getService = NSSelectorFromString(@"getService:");

    if (mgrClass && [contextClass respondsToSelector:activeUserContext]) {
        id context = [self invokeSelector:activeUserContext target:contextClass arguments:@[]];
        id center = [self invokeSelector:serviceCenter target:context arguments:@[]];
        if ([center respondsToSelector:getService]) {
            id service = [self invokeSelector:getService target:center arguments:@[mgrClass]];
            if (service) return service;
        }
    }

    Class serviceCenterClass = NSClassFromString(@"MMServiceCenter");
    SEL defaultCenter = NSSelectorFromString(@"defaultCenter");

    if (mgrClass && [serviceCenterClass respondsToSelector:defaultCenter]) {
        id center = [self invokeSelector:defaultCenter target:serviceCenterClass arguments:@[]];
        if ([center respondsToSelector:getService]) {
            id service = [self invokeSelector:getService target:center arguments:@[mgrClass]];
            if (service) return service;
        }
    }

    return nil;
}

+ (UIViewController *)rewardHostViewController {
    UIWindow *keyWindow = nil;
    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
        if (keyWindow) break;
    }
    if (!keyWindow) {
        id<UIApplicationDelegate> delegate = app.delegate;
        if ([delegate respondsToSelector:@selector(window)]) keyWindow = delegate.window;
    }

    UIViewController *controller = keyWindow.rootViewController;
    BOOL advanced = YES;
    while (controller && advanced) {
        advanced = NO;
        if ([controller isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (selected) {
                controller = selected;
                advanced = YES;
                continue;
            }
        }
        if ([controller isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if (visible) {
                controller = visible;
                advanced = YES;
                continue;
            }
        }
        if (controller.presentedViewController) {
            controller = controller.presentedViewController;
            advanced = YES;
        }
    }
    return controller;
}

+ (id)newLogicControllerWithViewController:(UIViewController *)viewController logicParams:(id)logicParams {
    SEL initSelector = NSSelectorFromString(@"initWithViewController:logicParams:");
    id controller = [self allocClassNamed:@"ScanQRCodeLogicController"];
    if ([controller respondsToSelector:initSelector]) {
        id result = [self invokeSelector:initSelector target:controller arguments:@[viewController ?: (id)kCFNull, logicParams ?: (id)kCFNull]];
        if (result) return result;
    }

    return [self newObjectNamed:@"ScanQRCodeLogicController"];
}

+ (id)newScannerWithDelegate:(id)delegate scannerParams:(id)scannerParams {
    SEL initSelector = NSSelectorFromString(@"initWithDelegate:scannerParams:");
    id scanner = [self allocClassNamed:@"NewQRCodeScanner"];
    if ([scanner respondsToSelector:initSelector]) {
        id result = [self invokeSelector:initSelector target:scanner arguments:@[delegate ?: (id)kCFNull, scannerParams ?: (id)kCFNull]];
        if (result) return result;
    }

    return [self newObjectNamed:@"NewQRCodeScanner"];
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
    CGFloat side = MIN(w, h) * 0.52;
    CGRect rect = CGRectMake((w - side) / 2.0, h * 0.12, side, side);
    UIImage *cropped = [self croppedImage:image rect:rect];
    return cropped ?: image;
}

+ (BOOL)scanRewardImage:(UIImage *)image withWeChatFromViewController:(UIViewController *)viewController {
    if (!image) return NO;

    UIViewController *hostController = viewController ?: [self rewardHostViewController];

    id logicParams = [self newLogicParams];
    if (!logicParams) return NO;

    id scannerParams = [self newScannerParams];

    id logicController = [self newLogicControllerWithViewController:hostController logicParams:logicParams];
    if (!logicController) return NO;

    id resultsManager = [self scanResultsManager];
    SEL setScanLogicController = NSSelectorFromString(@"setScanLogicController:");
    if ([resultsManager respondsToSelector:setScanLogicController]) {
        [self invokeSelector:setScanLogicController target:resultsManager arguments:@[logicController]];
    }

    id scanner = [self newScannerWithDelegate:logicController scannerParams:scannerParams];
    SEL scanOnePicture = NSSelectorFromString(@"scanOnePicture:");
    if (!scanner || ![scanner respondsToSelector:scanOnePicture]) return NO;

    NSMutableArray *retained = [self activeScanObjects];
    NSArray *scanObjects = @[hostController ?: (id)kCFNull, logicParams, scannerParams ?: (id)kCFNull, logicController, resultsManager ?: (id)kCFNull, scanner, image];
    [retained addObject:scanObjects];

    [self invokeSelector:scanOnePicture target:scanner arguments:@[image]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[self activeScanObjects] removeObject:scanObjects];
    });

    return YES;
}

+ (void)showToast:(NSString *)msg {
    if (msg.length == 0) return;

    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
        if (keyWindow) break;
    }
    if (!keyWindow) {
        id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
        if ([delegate respondsToSelector:@selector(window)]) keyWindow = delegate.window;
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
