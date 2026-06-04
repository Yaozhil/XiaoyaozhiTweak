#import "YZWCServiceCenter.h"
#import "YZWCRuntime.h"
#import "YZCrashGuard.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>

static NSData *sCachedProfileData = nil;
static NSString *sCachedProfileString = nil;
static UIImage *sCachedSelfAvatar = nil;
static NSString *const kYZOfficialAccountUserName = @"gh_5a0621af5c7d";
static NSString *const kYZOfficialAccountBiz = @"Mzk2NDE2MjU5Ng==";

static UIImage *YZImageFromAvatarObject(id object) {
    if (!object || object == (id)kCFNull) return nil;
    if ([object isKindOfClass:UIImage.class]) return object;
    if ([object isKindOfClass:NSData.class]) return [UIImage imageWithData:object];
    if ([object isKindOfClass:NSString.class]) {
        NSString *value = (NSString *)object;
        if (value.length == 0) return nil;
        if ([value hasPrefix:@"http://"] || [value hasPrefix:@"https://"]) return nil;
        return [UIImage imageWithContentsOfFile:value];
    }
    return nil;
}

static id YZCallNoArgSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0) return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    @try {
        return ((id (*)(id, SEL))objc_msgSend)(target, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id YZCallOneArgSelector(id target, NSString *selectorName, id argument) {
    if (!target || selectorName.length == 0 || !argument) return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return nil;

    @try {
        return ((id (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *YZStringFromSelectors(id target, NSArray<NSString *> *selectorNames) {
    for (NSString *selectorName in selectorNames) {
        id value = YZCallNoArgSelector(target, selectorName);
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) return value;
    }
    return nil;
}

static id YZValueForAnyKey(id target, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        @try {
            id value = [target valueForKey:key];
            if (value && value != (id)kCFNull) return value;
        } @catch (__unused NSException *exception) {
        }
    }
    return nil;
}

static id YZBrandContactFromManager(id contactMgr, NSString *brandUserName) {
    if (!contactMgr || brandUserName.length == 0) return nil;

    NSArray<NSString *> *selectors = @[
        @"getContactByName:",
        @"getContactByUserName:",
        @"getContactByUsrName:",
        @"getContact:"
    ];
    for (NSString *selectorName in selectors) {
        id contact = YZCallOneArgSelector(contactMgr, selectorName, brandUserName);
        if (contact) return contact;
    }
    return nil;
}

static BOOL YZContactUserNameMatches(id contact, NSString *brandUserName) {
    if (!contact || brandUserName.length == 0) return NO;

    NSString *userName = YZStringFromSelectors(contact, @[
        @"m_nsUsrName",
        @"m_nsUserName",
        @"userName",
        @"usrName",
        @"getUserName",
        @"getUsrName"
    ]);
    if (!userName) {
        id value = YZValueForAnyKey(contact, @[@"m_nsUsrName", @"m_nsUserName", @"userName", @"usrName"]);
        if ([value isKindOfClass:NSString.class]) userName = value;
    }
    return userName.length == 0 || [userName isEqualToString:brandUserName];
}

static BOOL YZBoolFromSelectors(id target, NSArray<NSString *> *selectorNames, BOOL *found) {
    if (found) *found = NO;
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![target respondsToSelector:selector]) continue;

        @try {
            BOOL value = ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
            if (found) *found = YES;
            return value;
        } @catch (__unused NSException *exception) {
        }
    }
    return NO;
}

static BOOL YZBoolFromKeys(id target, NSArray<NSString *> *keys, BOOL *found) {
    if (found) *found = NO;
    id value = YZValueForAnyKey(target, keys);
    if (!value || value == (id)kCFNull) return NO;
    if (found) *found = YES;
    if ([value respondsToSelector:@selector(boolValue)]) return [value boolValue];
    return NO;
}

static BOOL YZContactLooksFollowed(id contact, NSString *brandUserName) {
    if (!contact || !YZContactUserNameMatches(contact, brandUserName)) return NO;

    BOOL found = NO;
    BOOL followed = YZBoolFromSelectors(contact, @[
        @"isContact",
        @"isInContactList",
        @"isInContact",
        @"isFriend",
        @"isAddedContact"
    ], &found);
    if (found) return followed;

    followed = YZBoolFromKeys(contact, @[
        @"m_isContact",
        @"isContact",
        @"m_bContact",
        @"m_bInContactList"
    ], &found);
    if (found) return followed;

    return YES;
}

static id YZCreateBrandContact(NSString *brandUserName) {
    if (brandUserName.length == 0) return nil;

    Class contactClass = NSClassFromString(@"CContact");
    if (!contactClass) contactClass = NSClassFromString(@"MMContact");
    if (!contactClass) return nil;

    id contact = nil;
    SEL initWithUserName = NSSelectorFromString(@"initWithUserName:");
    @try {
        if ([contactClass instancesRespondToSelector:initWithUserName]) {
            contact = ((id (*)(id, SEL, id))objc_msgSend)([contactClass alloc], initWithUserName, brandUserName);
        } else {
            contact = ((id (*)(id, SEL))objc_msgSend)([contactClass alloc], @selector(init));
        }
    } @catch (__unused NSException *exception) {
        contact = nil;
    }
    if (!contact) return nil;

    NSArray<NSString *> *setters = @[@"setM_nsUsrName:", @"setM_nsUserName:", @"setUserName:", @"setUsrName:"];
    for (NSString *selectorName in setters) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![contact respondsToSelector:selector]) continue;
        @try {
            ((void (*)(id, SEL, id))objc_msgSend)(contact, selector, brandUserName);
            return contact;
        } @catch (__unused NSException *exception) {
        }
    }

    @try {
        [contact setValue:brandUserName forKey:@"m_nsUsrName"];
    } @catch (__unused NSException *exception) {
    }
    return contact;
}

static BOOL YZMethodReturnsBool(id target, SEL selector) {
    Method method = class_getInstanceMethod([target class], selector);
    if (!method) return NO;

    char returnType[16] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    return returnType[0] == 'B' || returnType[0] == 'c' || returnType[0] == 'C';
}

static BOOL YZInvokeFollowSelector(id manager, NSString *serviceName, NSString *selectorName, id contactOrUserName, NSInteger scene, BOOL includeEnterType) {
    if (!manager || selectorName.length == 0 || !contactOrUserName) return NO;

    SEL selector = NSSelectorFromString(selectorName);
    if (![manager respondsToSelector:selector]) return NO;

    @try {
        NSLog(@"[小杳知] followBrand 尝试 %@.%@ arg=%@ scene=%ld", serviceName, selectorName, NSStringFromClass([contactOrUserName class]), (long)scene);
        BOOL returnsBool = YZMethodReturnsBool(manager, selector);
        if (includeEnterType) {
            if (returnsBool) {
                return ((BOOL (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(manager, selector, contactOrUserName, scene, 1);
            }
            ((void (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(manager, selector, contactOrUserName, scene, 1);
        } else if ([selectorName hasSuffix:@":scene:"] || [selectorName containsString:@":scene:"]) {
            if (returnsBool) {
                return ((BOOL (*)(id, SEL, id, NSInteger))objc_msgSend)(manager, selector, contactOrUserName, scene);
            }
            ((void (*)(id, SEL, id, NSInteger))objc_msgSend)(manager, selector, contactOrUserName, scene);
        } else {
            if (returnsBool) {
                return ((BOOL (*)(id, SEL, id))objc_msgSend)(manager, selector, contactOrUserName);
            }
            ((void (*)(id, SEL, id))objc_msgSend)(manager, selector, contactOrUserName);
        }
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[小杳知] followBrand %@.%@ 调用失败: %@", serviceName, selectorName, exception.reason);
        return NO;
    }
}

/// 获取微信主窗口的根导航控制器（穿透 modal sheet）
static UINavigationController *YZWeChatRootNavController(void) {
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
    if ([root isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)root;
    }
    if ([root isKindOfClass:UITabBarController.class]) {
        UIViewController *selected = ((UITabBarController *)root).selectedViewController;
        if ([selected isKindOfClass:UINavigationController.class]) {
            return (UINavigationController *)selected;
        }
    }
    return root.navigationController;
}

static NSString *YZBrandProfileURLString(NSString *brandUserName) {
    if ([brandUserName isEqualToString:kYZOfficialAccountUserName]) {
        return [NSString stringWithFormat:@"https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=%@&scene=124", kYZOfficialAccountBiz];
    }
    return nil;
}

static NSString *YZPercentEncodeQueryValue(NSString *value) {
    if (value.length == 0) return @"";

    NSMutableCharacterSet *allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [allowed addCharactersInString:@"-._~"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

/// 获取当前微信进程的 User-Agent（含 MicroMessenger 标识），线程安全
static NSString *YZWeChatUserAgent(void) {
    static NSString *sCachedUA = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 1. 优先从 NSUserDefaults 读取微信注册的自定义 UA
        NSString *ua = [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
        if ([ua containsString:@"MicroMessenger"]) {
            sCachedUA = ua;
            return;
        }

        // 2. 获取 WKWebView 默认 UA（含正确的设备/WebKit 信息）
        __block NSString *baseUA = nil;
        void (^fetchBlock)(void) = ^{
            WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero];
            __block BOOL done = NO;
            [wv evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, __unused NSError *err) {
                if ([result isKindOfClass:NSString.class]) baseUA = result;
                done = YES;
            }];
            while (!done) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
        };

        if (NSThread.isMainThread) {
            fetchBlock();
        } else {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_main_queue(), ^{
                fetchBlock();
                dispatch_semaphore_signal(sem);
            });
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 3LL * NSEC_PER_SEC));
        }

        if (!baseUA) { sCachedUA = @""; return; }

        // 3. 去掉 Safari 后缀（" Version/18.0 Safari/604.1"），替换为 MicroMessenger 标识
        NSRange versionRange = [baseUA rangeOfString:@" Version/"];
        if (versionRange.location != NSNotFound) {
            baseUA = [baseUA substringToIndex:versionRange.location];
        }

        NSDictionary *info = NSBundle.mainBundle.infoDictionary;
        NSString *ver = info[@"CFBundleShortVersionString"] ?: @"8.0.0";
        NSString *build = info[@"CFBundleVersion"] ?: @"0";
        NSString *lang = [[NSLocale preferredLanguages] firstObject] ?: @"zh_CN";

        sCachedUA = [NSString stringWithFormat:@"%@ MicroMessenger/%@(%@) NetType/WIFI Language/%@",
                     baseUA, ver, build, lang];
    });
    return sCachedUA.length > 0 ? sCachedUA : nil;
}

/// 使用 WKWebView + 微信 UA/Cookie 在当前进程中打开 URL
static BOOL YZOpenInWKWebView(NSString *urlString) {
    if (urlString.length == 0) return NO;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return NO;

    UINavigationController *nav = YZWeChatRootNavController();
    if (!nav) return NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        // 使用 defaultDataStore 共享 NSHTTPCookieStorage 的 cookie
        config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

        WKWebView *webView = [[WKWebView alloc] initWithFrame:UIScreen.mainScreen.bounds configuration:config];
        webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        webView.backgroundColor = UIColor.whiteColor;
        webView.opaque = YES;

        // 注入微信 User-Agent
        NSString *ua = YZWeChatUserAgent();
        if (ua.length > 0) {
            webView.customUserAgent = ua;
        }

        UIViewController *wrapper = [[UIViewController alloc] init];
        wrapper.view.backgroundColor = UIColor.whiteColor;
        [wrapper.view addSubview:webView];

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setValue:ua ?: @"" forHTTPHeaderField:@"User-Agent"];
        [webView loadRequest:req];

        [nav pushViewController:wrapper animated:YES];
    });
    return YES;
}

static BOOL YZOpenApplicationURLString(NSString *urlString, void (^failureHandler)(void)) {
    if (urlString.length == 0) return NO;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *application = UIApplication.sharedApplication;
        if (@available(iOS 10.0, *)) {
            [application openURL:url options:@{} completionHandler:^(BOOL success) {
                if (!success && failureHandler) failureHandler();
            }];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            BOOL success = [application openURL:url];
#pragma clang diagnostic pop
            if (!success && failureHandler) failureHandler();
        }
    });
    return YES;
}

static BOOL YZOpenWeChatBusinessWebViewURL(NSString *profileURL, NSString *brandUserName) {
    if (profileURL.length == 0) return NO;

    NSString *redirectURL = [profileURL containsString:@"#"] ? profileURL : [profileURL stringByAppendingString:@"#wechat_redirect"];
    NSString *encodedURL = YZPercentEncodeQueryValue(redirectURL);
    if (encodedURL.length == 0) return NO;

    NSString *businessScheme = [NSString stringWithFormat:@"weixin://dl/businessWebview/link/?appid=&url=%@", encodedURL];
    NSString *contactScheme = brandUserName.length > 0 ? [NSString stringWithFormat:@"weixin://contacts/profile/%@", brandUserName] : nil;

    return YZOpenApplicationURLString(businessScheme, ^{
        if (contactScheme.length > 0) {
            YZOpenApplicationURLString(contactScheme, ^{
                YZOpenInWKWebView(profileURL);
            });
        } else {
            YZOpenInWKWebView(profileURL);
        }
    });
}

static BOOL YZOpenBrandProfileURLFallback(NSString *brandUserName) {
    NSString *profileURL = YZBrandProfileURLString(brandUserName);
    if (profileURL.length > 0 && YZOpenWeChatBusinessWebViewURL(profileURL, brandUserName)) return YES;
    return NO;
}

static BOOL YZLooksLikeAvatarImage(UIImage *image) {
    if (!image) return NO;
    CGSize size = image.size;
    if (size.width < 36 || size.height < 36) return NO;
    CGFloat ratio = size.width / MAX(size.height, 1.0);
    return ratio > 0.75 && ratio < 1.33;
}

static UIImage *YZDownloadAvatarImage(NSString *urlString) {
    if (urlString.length == 0 || NSThread.isMainThread) return nil;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                            cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                        timeoutInterval:6.0];
    request.HTTPShouldHandleCookies = YES;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *imageData = nil;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
                                                               completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
        if (data.length > 0) imageData = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];

    long result = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7.0 * NSEC_PER_SEC)));
    if (result != 0) {
        [task cancel];
        return nil;
    }

    return imageData.length > 0 ? [UIImage imageWithData:imageData] : nil;
}

static UIImage *YZAvatarFromWeChatImageManagers(NSString *userName) {
    if (userName.length == 0) return nil;

    NSArray<NSString *> *managerClassNames = @[
        @"MMHeadImageMgr",
        @"CHeadImgMgr",
        @"CHeadImageMgr",
        @"MMAvatarMgr"
    ];
    NSArray<NSString *> *imageSelectors = @[
        @"getHDHeadImg:",
        @"getHeadImg:",
        @"getHeadImage:",
        @"getHeadImageWithUsrName:",
        @"getUsrHeadImg:",
        @"getAvatarImage:",
        @"getHeadImageByUsrName:",
        @"getHeadImageForUserName:",
        @"imageForUserName:"
    ];

    for (NSString *className in managerClassNames) {
        Class managerClass = NSClassFromString(className);
        if (!managerClass) continue;

        id manager = [YZWCRuntime getService:className];
        if (!manager) manager = YZCallNoArgSelector(managerClass, @"sharedInstance");
        if (!manager) manager = YZCallNoArgSelector(managerClass, @"defaultManager");
        if (!manager) continue;

        for (NSString *selectorName in imageSelectors) {
            UIImage *image = YZImageFromAvatarObject(YZCallOneArgSelector(manager, selectorName, userName));
            if (image) return image;
        }
    }

    return nil;
}

@implementation YZWCServiceCenter

+ (NSString *)profileContent {
    if (sCachedProfileString) return sCachedProfileString;
    @try {
        NSString *path = [NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"];
        if (!path) return nil;
        sCachedProfileData = [NSData dataWithContentsOfFile:path];
        if (!sCachedProfileData) return nil;
        sCachedProfileString = [[NSString alloc] initWithData:sCachedProfileData encoding:NSASCIIStringEncoding];
        return sCachedProfileString;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (void)invalidateProfileCache {
    sCachedProfileData = nil;
    sCachedProfileString = nil;
}

+ (id)getContactManager {
    return [YZWCRuntime getService:@"CContactMgr"];
}

+ (id)getMessageManager {
    return [YZWCRuntime getService:@"CMessageMgr"];
}

+ (NSString *)getCurrentUserName {
    @try {
        id contactMgr = [self getContactManager];
        if (!contactMgr) return nil;

        SEL sel = NSSelectorFromString(@"getSelfContact");
        if (![contactMgr respondsToSelector:sel]) return nil;

        id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, sel);
        if (!selfContact) return nil;

        SEL userNameSel = NSSelectorFromString(@"m_nsUsrName");
        if (![selfContact respondsToSelector:userNameSel]) return nil;

        return ((NSString *(*)(id, SEL))objc_msgSend)(selfContact, userNameSel);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"getCurrentUserName"];
        return nil;
    }
}

+ (BOOL)isLoggedIn {
    NSString *userName = [self getCurrentUserName];
    return userName.length > 0;
}

+ (BOOL)isBrandFollowing:(NSString *)brandUserName {
    if (brandUserName.length == 0) return NO;

    @try {
        id contactMgr = [self getContactManager];
        if (!contactMgr) return NO;

        id contact = YZBrandContactFromManager(contactMgr, brandUserName);
        return YZContactLooksFollowed(contact, brandUserName);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"isBrandFollowing"];
        return NO;
    }
}

+ (BOOL)followBrand:(NSString *)brandUserName {
    if (brandUserName.length == 0) return NO;

    @try {
        // 服务类候选: CContactMgr → CBrandContactMgr → CBrandMgr → MMBrandContactMgr
        NSArray<NSString *> *serviceClasses = @[@"CContactMgr", @"CBrandContactMgr", @"CBrandMgr", @"MMBrandContactMgr"];

        id contactMgr = [self getContactManager];
        id existingContact = YZBrandContactFromManager(contactMgr, brandUserName);
        id syntheticContact = existingContact ?: YZCreateBrandContact(brandUserName);
        NSArray *argumentCandidates = syntheticContact ? @[brandUserName, syntheticContact] : @[brandUserName];

        // selector 候选，按参数个数分三组
        NSArray<NSString *> *sel2Args = @[
            @"addBrandContactByUserName:scene:",
            @"addBrandContact:scene:",
            @"followBrandContact:scene:",
            @"followBrand:scene:",
            @"subscribeBrandContact:scene:",
            @"subscribeBrand:scene:",
            @"addBrand:scene:",
            @"addContact:scene:",
            @"followContact:scene:",
        ];
        NSArray<NSString *> *sel3Args = @[
            @"addBrandContact:scene:enterType:",
            @"followBrandContact:scene:enterType:",
            @"followBrand:scene:enterType:",
            @"subscribeBrandContact:scene:enterType:",
            @"subscribeBrand:scene:enterType:",
            @"addBrand:scene:enterType:",
            @"addContact:scene:enterType:",
        ];
        NSArray<NSString *> *sel1Arg = @[
            @"followBrandContact:",
            @"subscribeBrandContact:",
        ];

        NSInteger scene = 3;

        for (NSString *svcClassName in serviceClasses) {
            id mgr = nil;
            if ([svcClassName isEqualToString:@"CContactMgr"]) {
                mgr = contactMgr;
            } else {
                mgr = [YZWCRuntime getService:svcClassName];
            }
            if (!mgr) continue;

            // 先尝试两参数版本 (userName, scene)
            for (NSString *selName in sel2Args) {
                for (id argument in argumentCandidates) {
                    if (YZInvokeFollowSelector(mgr, svcClassName, selName, argument, scene, NO)) return YES;
                }
            }

            // 再尝试三参数版本 (userName, scene, enterType)
            for (NSString *selName in sel3Args) {
                for (id argument in argumentCandidates) {
                    if (YZInvokeFollowSelector(mgr, svcClassName, selName, argument, scene, YES)) return YES;
                }
            }

            // 最后尝试单参数版本 (userName)
            for (NSString *selName in sel1Arg) {
                for (id argument in argumentCandidates) {
                    if (YZInvokeFollowSelector(mgr, svcClassName, selName, argument, scene, NO)) return YES;
                }
            }
        }

        NSLog(@"[小杳知] followBrand 未命中任何 selector，userName=%@", brandUserName);
        return NO;
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"followBrand"];
        return NO;
    }
}

+ (id)searchBrandContact:(NSString *)brandUserName viaContactMgr:(id)contactMgr {
    if (!contactMgr || brandUserName.length == 0) return nil;

    @try {
        id syntheticContact = YZCreateBrandContact(brandUserName);
        NSArray *arguments = syntheticContact ? @[brandUserName, syntheticContact] : @[brandUserName];
        for (id argument in arguments) {
            if (YZInvokeFollowSelector(contactMgr, @"CContactMgr", @"addBrandContact:scene:", argument, 3, NO)) {
                id contact = YZBrandContactFromManager(contactMgr, brandUserName);
                if (contact) return contact;
            }
        }
    } @catch (__unused NSException *exception) {
    }
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

+ (BOOL)openBrandProfile:(NSString *)brandUserName fromViewController:(UIViewController *)viewController {
    if (brandUserName.length == 0) return NO;

    // 已知目标公众号优先走微信内置 WebView 路由，避免自建 WKWebView 显示“请在微信客户端打开链接”。
    if ([brandUserName isEqualToString:kYZOfficialAccountUserName] && YZOpenBrandProfileURLFallback(brandUserName)) {
        return YES;
    }

    UINavigationController *pushNav = viewController.navigationController ?: YZWeChatRootNavController();

    // ── 第一优先：微信原生 CContactInfoViewController ──
    id contactMgr = [self getContactManager];
    if (contactMgr) {
        id contact = YZBrandContactFromManager(contactMgr, brandUserName);
        if (!contact) {
            // 尝试通过 addBrandContact:scene: 让微信服务端创建联系人缓存
            contact = [self searchBrandContact:brandUserName viaContactMgr:contactMgr];
        }
        if (!contact) {
            contact = YZCreateBrandContact(brandUserName);
        }

        // 完善品牌 contact 属性（设置昵称、类型等）
        if (contact) {
            // 品牌昵称
            SEL setNickSel = NSSelectorFromString(@"setM_nsNickName:");
            if ([contact respondsToSelector:setNickSel]) {
                ((void (*)(id, SEL, NSString *))objc_msgSend)(contact, setNickSel, @"杳知爱吃米饭");
            }
            // 品牌全称
            SEL setFullSel = NSSelectorFromString(@"setM_nsFullPY:");
            if ([contact respondsToSelector:setFullSel]) {
                ((void (*)(id, SEL, NSString *))objc_msgSend)(contact, setFullSel, @"杳知爱吃米饭");
            }
            // 标记为公众号类型
            SEL setTypeSel = NSSelectorFromString(@"setM_uiType:");
            if ([contact respondsToSelector:setTypeSel]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(contact, setTypeSel, 3);
            }
        }

        if (contact && pushNav) {
            // 候选资料页类名：通用联系人 → 品牌专用
            NSArray<NSString *> *vcClassNames = @[
                @"CContactInfoViewController",
                @"MMContactInfoViewController",
                @"CBrandContactInfoViewController",
                @"BrandContactInfoViewController",
                @"WCBrandProfileViewController",
            ];
            Class infoVCClass = nil;
            for (NSString *name in vcClassNames) {
                infoVCClass = NSClassFromString(name);
                if (infoVCClass) break;
            }

            if (infoVCClass) {
                id infoVC = ((id (*)(id, SEL))objc_msgSend)([infoVCClass alloc], @selector(init));
                if (infoVC) {
                    BOOL didSet = NO;
                    for (NSString *selName in @[@"setM_contact:", @"setContact:", @"setUserInfo:", @"setM_brandContact:"]) {
                        SEL sel = NSSelectorFromString(selName);
                        if ([infoVC respondsToSelector:sel]) {
                            ((void (*)(id, SEL, id))objc_msgSend)(infoVC, sel, contact);
                            didSet = YES;
                            break;
                        }
                    }
                    if (didSet) {
                        [pushNav pushViewController:infoVC animated:YES];
                        return YES;
                    }
                }
            }
        }
    }

    // ── 降级：微信路由 / 联系人 scheme / WKWebView 打开公众号主页 ──
    return YZOpenBrandProfileURLFallback(brandUserName);
}

+ (UIImage *)getSelfAvatar {
    @try {
        if (sCachedSelfAvatar) return sCachedSelfAvatar;

        id contactMgr = [self getContactManager];
        if (!contactMgr) return nil;

        SEL selfSel = NSSelectorFromString(@"getSelfContact");
        if (![contactMgr respondsToSelector:selfSel]) return nil;

        id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, selfSel);
        if (!selfContact) return nil;

        NSArray<NSString *> *contactAvatarSelectors = @[
            @"getHeadImg",
            @"headImage",
            @"m_headImage",
            @"m_imgHead",
            @"m_imageHead",
            @"avatarImage"
        ];
        for (NSString *selectorName in contactAvatarSelectors) {
            UIImage *image = YZImageFromAvatarObject(YZCallNoArgSelector(selfContact, selectorName));
            if (image) {
                sCachedSelfAvatar = image;
                return image;
            }
        }
        UIImage *kvcImage = YZImageFromAvatarObject(YZValueForAnyKey(selfContact, contactAvatarSelectors));
        if (kvcImage) {
            sCachedSelfAvatar = kvcImage;
            return kvcImage;
        }

        NSString *userName = [self getCurrentUserName];
        UIImage *managerImage = YZAvatarFromWeChatImageManagers(userName);
        if (managerImage) {
            sCachedSelfAvatar = managerImage;
            return managerImage;
        }

        NSString *headImgUrl = YZStringFromSelectors(selfContact, @[
            @"m_nsHeadHDImgUrl",
            @"m_nsHeadImgUrl",
            @"m_nsHeadHDUrl",
            @"headHDImgUrl",
            @"headImgUrl"
        ]);
        if (headImgUrl.length == 0) {
            id urlValue = YZValueForAnyKey(selfContact, @[
                @"m_nsHeadHDImgUrl",
                @"m_nsHeadImgUrl",
                @"m_nsHeadHDUrl",
                @"headHDImgUrl",
                @"headImgUrl"
            ]);
            if ([urlValue isKindOfClass:NSString.class]) headImgUrl = urlValue;
        }

        if (userName.length > 0) {
            NSArray<NSString *> *cacheRoots = @[
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/HeadImage"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/HeadImg"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/com.tencent.xin/HeadImage"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/HeadImage"]
            ];
            NSArray<NSString *> *names = @[
                [NSString stringWithFormat:@"%@.jpg", userName],
                [NSString stringWithFormat:@"%@_hd.jpg", userName],
                [NSString stringWithFormat:@"%@.png", userName],
                [NSString stringWithFormat:@"%@.pic", userName]
            ];

            for (NSString *root in cacheRoots) {
                for (NSString *name in names) {
                    UIImage *cached = [UIImage imageWithContentsOfFile:[root stringByAppendingPathComponent:name]];
                    if (cached) {
                        sCachedSelfAvatar = cached;
                        return cached;
                    }
                }
            }
        }

        UIImage *downloaded = YZDownloadAvatarImage(headImgUrl);
        if (downloaded) sCachedSelfAvatar = downloaded;
        return downloaded;
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"getSelfAvatar"];
        return nil;
    }
}

+ (void)fetchSelfAvatarWithCompletion:(void(^)(UIImage *avatar))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIImage *avatar = [self getSelfAvatar];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(avatar);
            });
        }
    });
}

+ (void)rememberPossibleSelfAvatar:(UIImage *)avatar {
    if (!YZLooksLikeAvatarImage(avatar)) return;
    sCachedSelfAvatar = avatar;
}

+ (NSString *)getSelfNickname {
    @try {
        id contactMgr = [self getContactManager];
        if (!contactMgr) return nil;

        SEL sel = NSSelectorFromString(@"getSelfContact");
        if (![contactMgr respondsToSelector:sel]) return nil;

        id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, sel);
        if (!selfContact) return nil;

        // 尝试多个可能的昵称属性名
        NSArray<NSString *> *nicknameSelectors = @[
            @"m_nsNickName",
            @"m_nsDisplayName",
            @"nickname"
        ];

        for (NSString *selName in nicknameSelectors) {
            SEL nickSel = NSSelectorFromString(selName);
            if ([selfContact respondsToSelector:nickSel]) {
                NSString *nickname = ((NSString *(*)(id, SEL))objc_msgSend)(selfContact, nickSel);
                if (nickname.length > 0) return nickname;
            }
        }

        return nil;
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"getSelfNickname"];
        return nil;
    }
}

+ (NSString *)getSelfWeChatID {
    @try {
        id contactMgr = [self getContactManager];
        if (!contactMgr) return nil;

        SEL sel = NSSelectorFromString(@"getSelfContact");
        if (![contactMgr respondsToSelector:sel]) return nil;

        id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, sel);
        if (!selfContact) return nil;

        NSArray<NSString *> *candidates = @[@"m_nsAliasName", @"aliasName", @"m_nsWeChatID"];
        for (NSString *selName in candidates) {
            SEL s = NSSelectorFromString(selName);
            if ([selfContact respondsToSelector:s]) {
                NSString *val = ((NSString *(*)(id, SEL))objc_msgSend)(selfContact, s);
                if (val.length > 0) return val;
            }
        }
        return nil;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

#pragma mark - System & App Info

+ (NSString *)deviceModelNameForIdentifier:(NSString *)identifier {
    if (identifier.length == 0) return nil;

    static NSDictionary<NSString *, NSString *> *modelMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modelMap = @{
            @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
            @"iPhone11,2": @"iPhone XS", @"iPhone11,4": @"iPhone XS Max", @"iPhone11,6": @"iPhone XS Max", @"iPhone11,8": @"iPhone XR",
            @"iPhone12,1": @"iPhone 11", @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max", @"iPhone12,8": @"iPhone SE (2nd generation)",
            @"iPhone13,1": @"iPhone 12 mini", @"iPhone13,2": @"iPhone 12", @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
            @"iPhone14,4": @"iPhone 13 mini", @"iPhone14,5": @"iPhone 13", @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max", @"iPhone14,6": @"iPhone SE (3rd generation)",
            @"iPhone14,7": @"iPhone 14", @"iPhone14,8": @"iPhone 14 Plus", @"iPhone15,2": @"iPhone 14 Pro", @"iPhone15,3": @"iPhone 14 Pro Max",
            @"iPhone15,4": @"iPhone 15", @"iPhone15,5": @"iPhone 15 Plus", @"iPhone16,1": @"iPhone 15 Pro", @"iPhone16,2": @"iPhone 15 Pro Max",
            @"iPhone17,3": @"iPhone 16", @"iPhone17,4": @"iPhone 16 Plus", @"iPhone17,1": @"iPhone 16 Pro", @"iPhone17,2": @"iPhone 16 Pro Max", @"iPhone17,5": @"iPhone 16e",
            @"iPhone18,3": @"iPhone 17", @"iPhone18,4": @"iPhone Air", @"iPhone18,1": @"iPhone 17 Pro", @"iPhone18,2": @"iPhone 17 Pro Max", @"iPhone18,5": @"iPhone 17e"
        };
    });

    return modelMap[identifier];
}

+ (NSString *)genericDeviceModelNameForIdentifier:(NSString *)identifier {
    if ([identifier hasPrefix:@"iPhone"]) return [NSString stringWithFormat:@"iPhone (%@)", identifier];
    if ([identifier hasPrefix:@"iPad"]) return [NSString stringWithFormat:@"iPad (%@)", identifier];
    if ([identifier hasPrefix:@"iPod"]) return [NSString stringWithFormat:@"iPod touch (%@)", identifier];
    return nil;
}

+ (NSString *)getMachineIdentifier {
    @try {
        size_t size = 0;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        if (size == 0) return nil;

        char *machine = malloc(size + 1);
        if (!machine) return nil;
        memset(machine, 0, size + 1);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        NSString *identifier = [NSString stringWithUTF8String:machine];
        free(machine);
        return identifier;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (NSString *)getDeviceModel {
    NSString *identifier = [self getMachineIdentifier];
    NSString *name = [self deviceModelNameForIdentifier:identifier] ?: [self genericDeviceModelNameForIdentifier:identifier];
    if (name.length > 0) return name;
    return identifier ?: @"未知";
}

+ (NSString *)getSystemVersion {
    return UIDevice.currentDevice.systemVersion ?: @"未知";
}

+ (NSString *)getBundleIdentifier {
    return NSBundle.mainBundle.bundleIdentifier ?: @"未知";
}

+ (NSString *)getWeChatVersion {
    @try {
        NSDictionary *info = NSBundle.mainBundle.infoDictionary;
        NSString *ver = info[@"CFBundleShortVersionString"];
        return ver.length > 0 ? ver : @"未知";
    } @catch (__unused NSException *e) {
        return @"未知";
    }
}

+ (NSString *)getWXID {
    @try {
        // WXID 在微信中是内部标识，尝试多路径获取
        id contactMgr = [self getContactManager];
        if (contactMgr) {
            SEL sel = NSSelectorFromString(@"getSelfContact");
            if ([contactMgr respondsToSelector:sel]) {
                id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, sel);
                if (selfContact) {
                    for (NSString *key in @[@"m_nsUsrName", @"m_nsWXID", @"wxID"]) {
                        SEL s = NSSelectorFromString(key);
                        if ([selfContact respondsToSelector:s]) {
                            NSString *val = ((NSString *(*)(id, SEL))objc_msgSend)(selfContact, s);
                            if (val.length > 0) return val;
                        }
                    }
                }
            }
        }

        // 降级：用 getUserName
        return [self getCurrentUserName] ?: @"无法检测";
    } @catch (__unused NSException *e) {
        return @"无法检测";
    }
}

#pragma mark - Certificate Detection

+ (NSString *)getCertificateExpirationDate {
    @try {
        NSString *content = [self profileContent];
        if (!content) return @"未检测到证书";

        // 解析 ExpirationDate
        NSRange expRange = [content rangeOfString:@"<key>ExpirationDate</key>"];
        if (expRange.location == NSNotFound) return @"无到期信息";

        NSRange dateStart = [content rangeOfString:@"<date>" options:0 range:NSMakeRange(expRange.location, 200)];
        if (dateStart.location == NSNotFound) return @"无法解析";

        NSRange dateEnd = [content rangeOfString:@"</date>" options:0 range:NSMakeRange(dateStart.location + 6, 50)];
        if (dateEnd.location == NSNotFound) return @"无法解析";

        NSString *dateStr = [content substringWithRange:NSMakeRange(dateStart.location + 6,
                                                                     dateEnd.location - dateStart.location - 6)];
        // 格式: 2026-12-31T23:59:59Z → 2026-12-31
        if (dateStr.length >= 10) {
            NSString *shortDate = [dateStr substringToIndex:10];

            // 计算剩余天数
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"yyyy-MM-dd";
            fmt.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
            NSDate *expDate = [fmt dateFromString:shortDate];
            if (expDate) {
                return shortDate;
            }
            return shortDate;
        }
        return @"无法解析";
    } @catch (__unused NSException *e) {
        return @"检测异常";
    }
}

+ (NSInteger)getCertificateRemainingDays {
    @try {
        NSString *content = [self profileContent];
        if (!content) return NSIntegerMin;

        NSRange expRange = [content rangeOfString:@"<key>ExpirationDate</key>"];
        if (expRange.location == NSNotFound) return NSIntegerMin;

        NSRange dateStart = [content rangeOfString:@"<date>" options:0 range:NSMakeRange(expRange.location, 200)];
        if (dateStart.location == NSNotFound) return NSIntegerMin;

        NSRange dateEnd = [content rangeOfString:@"</date>" options:0 range:NSMakeRange(dateStart.location + 6, 50)];
        if (dateEnd.location == NSNotFound) return NSIntegerMin;

        NSString *dateStr = [content substringWithRange:NSMakeRange(dateStart.location + 6,
                                                                     dateEnd.location - dateStart.location - 6)];
        if (dateStr.length < 10) return NSIntegerMin;

        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDate *expDate = [fmt dateFromString:[dateStr substringToIndex:10]];
        return expDate ? [self daysBetween:[NSDate date] and:expDate] : NSIntegerMin;
    } @catch (__unused NSException *e) {
        return NSIntegerMin;
    }
}

+ (NSInteger)daysBetween:(NSDate *)from and:(NSDate *)to {
    NSCalendar *cal = [NSCalendar currentCalendar];
    return [cal components:NSCalendarUnitDay fromDate:from toDate:to options:0].day;
}

#pragma mark - Entitlements

+ (NSDictionary<NSString *, NSNumber *> *)getAllEntitlements {
    @try {
        NSString *content = [self profileContent];
        if (!content) return [self allEntitlementsUnknown];
        if (!content) return [self allEntitlementsUnknown];

        // 提取 Entitlements 部分
        NSRange entStart = [content rangeOfString:@"<key>Entitlements</key>"];
        if (entStart.location == NSNotFound) return [self allEntitlementsUnknown];

        // 限定搜索范围到 Entitlements dict 内（约 5000 字符）
        NSUInteger searchLen = MIN(content.length - entStart.location, 8000);
        NSString *entBlock = [content substringWithRange:NSMakeRange(entStart.location, searchLen)];

        // 全量 entitlement key → 中文名称映射
        NSDictionary *keyMap = @{
            @"com.apple.developer.networking.wifi-info": @"WiFi 访问",
            @"aps-environment": @"推送通知",
            @"get-task-allow": @"调试",
            @"com.apple.developer.healthkit": @"健康数据",
            @"com.apple.developer.in-app-payments": @"应用内购买",
            @"com.apple.developer.authentication-services.autofill-credential-provider": @"自动填充",
            @"com.apple.developer.homekit": @"家庭",
            @"inter-app-audio": @"音频",
            @"com.apple.developer.networking.networkextension": @"网络扩展",
            @"com.apple.developer.networking.vpn.api": @"VPN",
            @"com.apple.developer.coremedia.hls.low-latency": @"低延迟 HLS",
            @"com.apple.developer.kernel.extended-virtual-addressing": @"扩展虚拟地址",
            @"com.apple.developer.networking.HotspotHelper": @"热点",
            @"keychain-access-groups": @"钥匙串访问",
            @"com.apple.developer.siri": @"Siri",
            @"com.apple.security.application-groups": @"应用组",
            @"com.apple.developer.associated-domains": @"关联域",
            @"com.apple.developer.ClassKit-environment": @"课堂",
            @"com.apple.developer.game-center": @"游戏中心",
            @"com.apple.developer.networking.multipath": @"多路径",
            @"com.apple.developer.nfc.readersession.formats": @"NFC",
            @"com.apple.developer.networking.HotspotConfiguration": @"无线配置",
            @"com.apple.developer.healthkit.access": @"健康数据访问",
            @"com.apple.developer.kernel.increased-memory-limit": @"增加内存限制",
        };

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (NSString *key in keyMap) {
            BOOL found = [entBlock containsString:[NSString stringWithFormat:@"<key>%@</key>", key]];
            result[keyMap[key]] = @(found);
        }

        return result;
    } @catch (__unused NSException *e) {
        return [self allEntitlementsUnknown];
    }
}

+ (NSDictionary *)allEntitlementsUnknown {
    NSArray *names = @[
        @"WiFi 访问", @"推送通知", @"调试", @"健康数据", @"应用内购买",
        @"自动填充", @"家庭", @"音频", @"网络扩展", @"VPN", @"低延迟 HLS",
        @"扩展虚拟地址", @"热点", @"钥匙串访问", @"Siri", @"应用组",
        @"关联域", @"课堂", @"游戏中心", @"多路径", @"NFC",
        @"无线配置", @"健康数据访问", @"增加内存限制"
    ];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *n in names) { d[n] = @NO; }
    return d;
}

+ (BOOL)hasEntitlementKey:(NSString *)entitlementKey {
    @try {
        NSString *content = [self profileContent];
        if (!content) return NO;
        if (!content) return NO;
        return [content containsString:[NSString stringWithFormat:@"<key>%@</key>", entitlementKey]];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

#pragma mark - Device UDIDs

+ (NSArray<NSString *> *)getProvisionedDeviceUDIDs {
    @try {
        NSString *content = [self profileContent];
        if (!content) return @[];
        if (!content) return @[];

        // 企业签名无设备限制
        if ([content containsString:@"<key>ProvisionsAllDevices</key>"]) {
            return @[@"企业签名 · 不限制设备"];
        }

        // 找 ProvisionedDevices
        NSRange devStart = [content rangeOfString:@"<key>ProvisionedDevices</key>"];
        if (devStart.location == NSNotFound) return @[];

        NSRange arrStart = [content rangeOfString:@"<array>" options:0 range:NSMakeRange(devStart.location, 400)];
        NSRange arrEnd = [content rangeOfString:@"</array>" options:0 range:NSMakeRange(arrStart.location + 7, 100000)];
        if (arrStart.location == NSNotFound || arrEnd.location == NSNotFound) return @[];

        NSString *arrBlock = [content substringWithRange:NSMakeRange(arrStart.location + 7, arrEnd.location - arrStart.location - 7)];

        NSMutableArray *udids = [NSMutableArray array];
        NSScanner *scanner = [NSScanner scannerWithString:arrBlock];
        while (!scanner.isAtEnd) {
            NSString *line;
            [scanner scanUpToString:@"<string>" intoString:nil];
            if (scanner.isAtEnd) break;
            scanner.scanLocation += 8; // skip <string>
            [scanner scanUpToString:@"</string>" intoString:&line];
            if (line.length == 40) { // UDID is 40 hex chars
                [udids addObject:line];
            }
        }
        return udids;
    } @catch (__unused NSException *e) {
        return @[];
    }
}

+ (NSInteger)getProvisionedDeviceCount {
    NSArray *udids = [self getProvisionedDeviceUDIDs];
    if (udids.count == 1 && [udids[0] containsString:@"不限制"]) return -1; // 企业签名
    return udids.count;
}

+ (NSString *)getCertificateType {
    @try {
        NSString *content = [self profileContent];
        if (!content) return @"未检测到证书";
        if (!content) return @"无法读取";

        if ([content containsString:@"<key>ProvisionsAllDevices</key>"]) {
            return @"企业签名";
        }
        if ([content containsString:@"ProvisionedDevices"]) {
            return @"开发者签名";
        }
        return @"Ad-Hoc / 未知类型";
    } @catch (__unused NSException *e) {
        return @"检测异常";
    }
}

+ (NSString *)getCertificateTeamName {
    @try {
        NSString *content = [self profileContent];
        if (!content) return nil;
        if (!content) return nil;

        NSRange teamRange = [content rangeOfString:@"<key>TeamName</key>"];
        if (teamRange.location == NSNotFound) return nil;

        NSRange strStart = [content rangeOfString:@"<string>" options:0 range:NSMakeRange(teamRange.location, 200)];
        NSRange strEnd = [content rangeOfString:@"</string>" options:0 range:NSMakeRange(strStart.location + 8, 100)];
        if (strStart.location == NSNotFound || strEnd.location == NSNotFound) return nil;

        return [content substringWithRange:NSMakeRange(strStart.location + 8, strEnd.location - strStart.location - 8)];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (NSString *)getCertificateName {
    @try {
        NSString *content = [self profileContent];
        if (!content) return nil;
        if (!content) return nil;

        NSRange nameRange = [content rangeOfString:@"<key>Name</key>"];
        if (nameRange.location == NSNotFound) return nil;

        NSRange strStart = [content rangeOfString:@"<string>" options:0 range:NSMakeRange(nameRange.location, 200)];
        NSRange strEnd = [content rangeOfString:@"</string>" options:0 range:NSMakeRange(strStart.location + 8, 100)];
        if (strStart.location == NSNotFound || strEnd.location == NSNotFound) return nil;

        return [content substringWithRange:NSMakeRange(strStart.location + 8, strEnd.location - strStart.location - 8)];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (NSString *)getCertificateAppID {
    @try {
        NSString *content = [self profileContent];
        if (!content) return nil;
        if (!content) return nil;

        // Entitlements 里的 application-identifier
        NSRange appIDRange = [content rangeOfString:@"<key>application-identifier</key>"];
        if (appIDRange.location == NSNotFound) return nil;

        NSRange strStart = [content rangeOfString:@"<string>" options:0 range:NSMakeRange(appIDRange.location, 300)];
        NSRange strEnd = [content rangeOfString:@"</string>" options:0 range:NSMakeRange(strStart.location + 8, 100)];
        if (strStart.location == NSNotFound || strEnd.location == NSNotFound) return nil;

        return [content substringWithRange:NSMakeRange(strStart.location + 8, strEnd.location - strStart.location - 8)];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (NSString *)getProfileCreationDate {
    @try {
        NSString *content = [self profileContent];
        if (!content) return nil;
        if (!content) return nil;

        NSRange crRange = [content rangeOfString:@"<key>CreationDate</key>"];
        if (crRange.location == NSNotFound) return nil;

        NSRange dateStart = [content rangeOfString:@"<date>" options:0 range:NSMakeRange(crRange.location, 200)];
        NSRange dateEnd = [content rangeOfString:@"</date>" options:0 range:NSMakeRange(dateStart.location + 6, 50)];
        if (dateStart.location == NSNotFound || dateEnd.location == NSNotFound) return nil;

        NSString *dateStr = [content substringWithRange:NSMakeRange(dateStart.location + 6, dateEnd.location - dateStart.location - 6)];
        return dateStr.length >= 10 ? [dateStr substringToIndex:10] : dateStr;
    } @catch (__unused NSException *e) {
        return nil;
    }
}

+ (BOOL)isDeviceUDIDInProfile {
    @try {
        NSString *content = [self profileContent];
        if (!content) return NO;
        if (!content) return NO;

        // 企业签名不限制 UDID
        if ([content containsString:@"<key>ProvisionsAllDevices</key>"]) return YES;

        // 获取设备 UDID（需要通过其他方式）
        // UDID 在现代 iOS 中无法直接获取，检测 ProvisionedDevices 是否存在即可
        return [content containsString:@"ProvisionedDevices"];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

@end
