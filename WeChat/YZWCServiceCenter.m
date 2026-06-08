#import "YZWCServiceCenter.h"
#import "YZWCRuntime.h"
#import "YZCrashGuard.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>
#import <sys/sysctl.h>

static NSData *sCachedProfileData = nil;
static NSString *sCachedProfileString = nil;
static UIImage *sCachedSelfAvatar = nil;
static NSString *const kYZOfficialAccountUserName = @"gh_5a0621af5c7d";
static NSString *const kYZOfficialAccountProfileURL = @"https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=Mzk2NDE2MjU5Ng==&scene=124";

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

static BOOL YZInvokeSelectorWithArguments(id target, NSString *selectorName, NSArray *arguments) {
    if (!target || selectorName.length == 0) return NO;
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) return NO;

    @try {
        NSMethodSignature *signature = [target methodSignatureForSelector:selector];
        if (!signature) return NO;
        NSUInteger argumentCount = signature.numberOfArguments > 2 ? signature.numberOfArguments - 2 : 0;
        if (argumentCount > arguments.count) return NO;

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = target;
        invocation.selector = selector;

        for (NSUInteger index = 0; index < argumentCount; index++) {
            id value = arguments[index];
            const char *type = [signature getArgumentTypeAtIndex:index + 2];
            while (*type == 'r' || *type == 'n' || *type == 'N' || *type == 'o' || *type == 'O' || *type == 'R' || *type == 'V') type++;

            if (type[0] == '@') {
                id objectValue = value == (id)kCFNull ? nil : value;
                [invocation setArgument:&objectValue atIndex:index + 2];
            } else if (strcmp(type, @encode(BOOL)) == 0 || strcmp(type, "B") == 0) {
                BOOL boolValue = [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
                [invocation setArgument:&boolValue atIndex:index + 2];
            } else if (strcmp(type, @encode(NSInteger)) == 0 ||
                       strcmp(type, @encode(NSUInteger)) == 0 ||
                       strcmp(type, @encode(int)) == 0 ||
                       strcmp(type, @encode(unsigned int)) == 0 ||
                       strcmp(type, @encode(long)) == 0 ||
                       strcmp(type, @encode(unsigned long)) == 0 ||
                       strcmp(type, @encode(long long)) == 0 ||
                       strcmp(type, @encode(unsigned long long)) == 0) {
                NSInteger integerValue = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
                [invocation setArgument:&integerValue atIndex:index + 2];
            } else {
                return NO;
            }
        }

        [invocation invoke];

        const char *returnType = signature.methodReturnType;
        while (*returnType == 'r' || *returnType == 'n' || *returnType == 'N' || *returnType == 'o' || *returnType == 'O' || *returnType == 'R' || *returnType == 'V') returnType++;
        if (strcmp(returnType, @encode(void)) == 0) return YES;
        if (strcmp(returnType, @encode(BOOL)) == 0 || strcmp(returnType, "B") == 0) {
            BOOL result = NO;
            [invocation getReturnValue:&result];
            return result;
        }
        if (returnType[0] == '@') {
            __unsafe_unretained id result = nil;
            [invocation getReturnValue:&result];
            return result != nil;
        }
        if (strcmp(returnType, @encode(NSInteger)) == 0 ||
            strcmp(returnType, @encode(NSUInteger)) == 0 ||
            strcmp(returnType, @encode(int)) == 0 ||
            strcmp(returnType, @encode(unsigned int)) == 0 ||
            strcmp(returnType, @encode(long)) == 0 ||
            strcmp(returnType, @encode(unsigned long)) == 0 ||
            strcmp(returnType, @encode(long long)) == 0 ||
            strcmp(returnType, @encode(unsigned long long)) == 0) {
            NSInteger result = 0;
            [invocation getReturnValue:&result];
            return result != 0;
        }
    } @catch (NSException *exception) {
        NSLog(@"[小杳知] URL selector %@ failed: %@", selectorName, exception.reason);
    }
    return NO;
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
        @"getContactForSearchByName:",
        @"getContact:"
    ];
    for (NSString *selectorName in selectors) {
        id contact = YZCallOneArgSelector(contactMgr, selectorName, brandUserName);
        if (contact) return contact;
    }
    return nil;
}

static id YZSearchBrandContactFromServer(id contactMgr, NSString *brandUserName) {
    if (!contactMgr || brandUserName.length == 0) return nil;

    return YZCallOneArgSelector(contactMgr, @"getContactForSearchByName:", brandUserName);
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
    return userName.length > 0 && [userName isEqualToString:brandUserName];
}

static BOOL YZBoolFromSelectors(id target, NSArray<NSString *> *selectorNames, BOOL *found) {
    if (found) *found = NO;
    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![target respondsToSelector:selector]) continue;

        @try {
            Method method = class_getInstanceMethod([target class], selector);
            char returnType[16] = {0};
            if (method) method_getReturnType(method, returnType, sizeof(returnType));
            if (returnType[0] == '@') {
                id value = ((id (*)(id, SEL))objc_msgSend)(target, selector);
                if ([value respondsToSelector:@selector(boolValue)]) {
                    if (found) *found = YES;
                    return [value boolValue];
                }
                continue;
            }
            if (strchr("BcCsSiIlLqQ", returnType[0])) {
                NSInteger value = ((NSInteger (*)(id, SEL))objc_msgSend)(target, selector);
                if (found) *found = YES;
                return value != 0;
            }
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

static BOOL YZBoolFromOneArgSelectors(id target, NSArray<NSString *> *selectorNames, id argument, BOOL *found) {
    if (found) *found = NO;
    if (!target || !argument) return NO;

    for (NSString *selectorName in selectorNames) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![target respondsToSelector:selector]) continue;

        @try {
            Method method = class_getInstanceMethod([target class], selector);
            char returnType[16] = {0};
            if (method) method_getReturnType(method, returnType, sizeof(returnType));
            if (returnType[0] == '@') {
                id value = ((id (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
                if ([value respondsToSelector:@selector(boolValue)]) {
                    if (found) *found = YES;
                    return [value boolValue];
                }
                continue;
            }
            if (strchr("BcCsSiIlLqQ", returnType[0])) {
                NSInteger value = ((NSInteger (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
                if (found) *found = YES;
                return value != 0;
            }
        } @catch (__unused NSException *exception) {
        }
    }
    return NO;
}

static NSInteger YZContactFollowState(id contact, NSString *brandUserName) {
    if (!contact || !YZContactUserNameMatches(contact, brandUserName)) return -1;

    BOOL found = NO;
    BOOL followed = YZBoolFromSelectors(contact, @[
        @"isSubscribed",
        @"isSubscribe",
        @"isBrandSubscribed",
        @"isBizSubscribed",
        @"isBizContactSubscribed",
        @"isOfficialAccountSubscribed"
    ], &found);
    if (found) return followed ? 1 : 0;

    followed = YZBoolFromKeys(contact, @[
        @"m_bSubscribed",
        @"m_isSubscribed",
        @"isSubscribed",
        @"is_subscribed",
        @"subscribed",
        @"m_isBrandSubscribed"
    ], &found);
    if (found) return followed ? 1 : 0;

    return -1;
}

static UINavigationController *YZWeChatRootNavController(void);

static UINavigationController *YZNavigationControllerFromViewController(UIViewController *viewController) {
    if (!viewController) return nil;
    NSString *className = NSStringFromClass(viewController.class);
    if ([className containsString:@"YZGlass"]) return nil;
    if ([viewController isKindOfClass:UINavigationController.class]) {
        return (UINavigationController *)viewController;
    }
    return viewController.navigationController;
}

static UINavigationController *YZPreferredPushNavigationController(UIViewController *viewController) {
    UINavigationController *nav = YZNavigationControllerFromViewController(viewController);
    return nav ?: YZWeChatRootNavController();
}

static BOOL YZShouldDismissBeforePresenting(UIViewController *viewController) {
    if (!viewController) return NO;
    NSString *className = NSStringFromClass(viewController.class);
    return [className containsString:@"YZGlass"] || viewController.presentingViewController != nil;
}

static BOOL YZAddUniqueTarget(NSMutableArray *targets, id target) {
    if (!target || target == (id)kCFNull) return NO;
    for (id existing in targets) {
        if (existing == target) return NO;
    }
    [targets addObject:target];
    return YES;
}

static NSArray *YZWeChatURLRouterTargets(void) {
    NSArray<NSString *> *classNames = @[
        @"MMURLHandler",
        @"MMURLRouter",
        @"MMURLService",
        @"MMOpenURLService",
        @"WCURLHandler",
        @"WCURLRouter",
        @"WCURLService",
        @"MMLinkHandler",
        @"WCLinkHandler",
        @"MMRouter",
        @"WCRouter"
    ];

    NSMutableArray *targets = [NSMutableArray array];
    for (NSString *className in classNames) {
        Class cls = NSClassFromString(className);
        if (!cls) continue;

        YZAddUniqueTarget(targets, [YZWCRuntime getService:className]);
        YZAddUniqueTarget(targets, YZCallNoArgSelector(cls, @"sharedInstance"));
        YZAddUniqueTarget(targets, YZCallNoArgSelector(cls, @"defaultCenter"));
        YZAddUniqueTarget(targets, YZCallNoArgSelector(cls, @"defaultManager"));
        YZAddUniqueTarget(targets, cls);
    }
    return targets;
}

static BOOL YZOpenURLThroughWeChatRouter(NSURL *url, UIViewController *viewController) {
    if (!url) return NO;

    NSString *urlString = url.absoluteString;
    NSDictionary *extraInfo = @{
        @"scene": @124,
        @"fromScene": @124,
        @"rawUrl": urlString
    };
    NSDictionary *options = @{
        @"scene": @124,
        @"fromScene": @124,
        @"extraInfo": extraInfo
    };
    UIViewController *presenter = viewController ?: nil;

    NSArray<NSDictionary<NSString *, id> *> *attempts = @[
        @{@"selector": @"openURLString:", @"args": @[urlString]},
        @{@"selector": @"openUrlString:", @"args": @[urlString]},
        @{@"selector": @"handleURLString:", @"args": @[urlString]},
        @{@"selector": @"openURL:", @"args": @[urlString]},
        @{@"selector": @"openUrl:", @"args": @[urlString]},
        @{@"selector": @"handleURL:", @"args": @[urlString]},
        @{@"selector": @"handleOpenURL:", @"args": @[urlString]},
        @{@"selector": @"openURLString:extraInfo:", @"args": @[urlString, extraInfo]},
        @{@"selector": @"openURLString:withExtraInfo:", @"args": @[urlString, extraInfo]},
        @{@"selector": @"openURLString:options:", @"args": @[urlString, options]},
        @{@"selector": @"openURLString:fromScene:", @"args": @[urlString, @124]},
        @{@"selector": @"openURLString:scene:", @"args": @[urlString, @124]},
        @{@"selector": @"openURL:extraInfo:", @"args": @[urlString, extraInfo]},
        @{@"selector": @"openURL:withExtraInfo:", @"args": @[urlString, extraInfo]},
        @{@"selector": @"openURL:options:", @"args": @[urlString, options]},
        @{@"selector": @"openURL:fromScene:", @"args": @[urlString, @124]},
        @{@"selector": @"openURL:scene:", @"args": @[urlString, @124]},
        @{@"selector": @"openURL:", @"args": @[url]},
        @{@"selector": @"openUrl:", @"args": @[url]},
        @{@"selector": @"handleURL:", @"args": @[url]},
        @{@"selector": @"handleOpenURL:", @"args": @[url]},
        @{@"selector": @"openURL:extraInfo:", @"args": @[url, extraInfo]},
        @{@"selector": @"openURL:withExtraInfo:", @"args": @[url, extraInfo]},
        @{@"selector": @"openURL:options:", @"args": @[url, options]},
        @{@"selector": @"openURL:fromScene:", @"args": @[url, @124]},
        @{@"selector": @"openURL:scene:", @"args": @[url, @124]}
    ];

    if (presenter) {
        attempts = [attempts arrayByAddingObjectsFromArray:@[
            @{@"selector": @"openURLString:fromViewController:", @"args": @[urlString, presenter]},
            @{@"selector": @"openURLString:viewController:", @"args": @[urlString, presenter]},
            @{@"selector": @"openURL:fromViewController:", @"args": @[urlString, presenter]},
            @{@"selector": @"openURL:viewController:", @"args": @[urlString, presenter]},
            @{@"selector": @"openURL:fromViewController:", @"args": @[url, presenter]},
            @{@"selector": @"openURL:viewController:", @"args": @[url, presenter]},
            @{@"selector": @"openURLString:fromViewController:extraInfo:", @"args": @[urlString, presenter, extraInfo]},
            @{@"selector": @"openURL:fromViewController:extraInfo:", @"args": @[urlString, presenter, extraInfo]},
            @{@"selector": @"openURL:fromViewController:extraInfo:", @"args": @[url, presenter, extraInfo]}
        ]];
    }

    for (id target in YZWeChatURLRouterTargets()) {
        for (NSDictionary<NSString *, id> *attempt in attempts) {
            NSString *selectorName = attempt[@"selector"];
            NSArray *arguments = attempt[@"args"];
            if (YZInvokeSelectorWithArguments(target, selectorName, arguments)) {
                NSLog(@"[小杳知] open official account url via %@ %@", NSStringFromClass([target class]), selectorName);
                return YES;
            }
        }
    }
    return NO;
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
    return [self brandFollowState:brandUserName] == 1;
}

+ (NSInteger)brandFollowState:(NSString *)brandUserName {
    if (brandUserName.length == 0) return -1;

    @try {
        id contactMgr = [self getContactManager];
        if (!contactMgr) return -1;

        BOOL found = NO;
        BOOL subscribed = YZBoolFromOneArgSelectors(contactMgr, @[
            @"isSubscribed:",
            @"isSubscribe:",
            @"isBrandSubscribed:",
            @"isBizSubscribed:",
            @"isOfficialAccountSubscribed:"
        ], brandUserName, &found);
        if (found) return subscribed ? 1 : 0;

        id contact = YZBrandContactFromManager(contactMgr, brandUserName);
        return YZContactFollowState(contact, brandUserName);
    } @catch (NSException *exception) {
        [YZCrashGuard logCrashContext:@"brandFollowState"];
        return -1;
    }
}

+ (BOOL)followBrand:(NSString *)brandUserName {
    if (brandUserName.length == 0) return NO;

    @try {
        NSArray<NSString *> *serviceClasses = @[@"CContactMgr", @"CBrandContactMgr", @"CBrandMgr", @"MMBrandContactMgr"];
        id contactMgr = [self getContactManager];
        id existingContact = YZBrandContactFromManager(contactMgr, brandUserName);
        NSArray *argumentCandidates = existingContact ? @[brandUserName, existingContact] : @[brandUserName];
        NSNumber *scene = @3;
        NSNumber *enterType = @0;

        for (NSString *svcClassName in serviceClasses) {
            id mgr = [svcClassName isEqualToString:@"CContactMgr"] ? contactMgr : [YZWCRuntime getService:svcClassName];
            if (!mgr) continue;

            for (id argument in argumentCandidates) {
                NSArray<NSDictionary<NSString *, id> *> *attempts = @[
                    @{@"selector": @"addBrandContactByUserName:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"addBrandContact:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"followBrandContact:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"followBrand:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"subscribeBrandContact:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"subscribeBrand:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"addBrand:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"addContact:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"followContact:scene:", @"args": @[argument, scene]},
                    @{@"selector": @"addBrandContact:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"followBrandContact:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"followBrand:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"subscribeBrandContact:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"subscribeBrand:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"addBrand:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"addContact:scene:enterType:", @"args": @[argument, scene, enterType]},
                    @{@"selector": @"followBrandContact:", @"args": @[argument]},
                    @{@"selector": @"subscribeBrandContact:", @"args": @[argument]},
                    @{@"selector": @"addBrandContact:", @"args": @[argument]},
                    @{@"selector": @"addContact:", @"args": @[argument]}
                ];

                for (NSDictionary<NSString *, id> *attempt in attempts) {
                    NSString *selectorName = attempt[@"selector"];
                    NSArray *arguments = attempt[@"args"];
                    if (YZInvokeSelectorWithArguments(mgr, selectorName, arguments)) {
                        NSLog(@"[小杳知] followBrand hit %@ %@", svcClassName, selectorName);
                        return YES;
                    }
                }
            }
        }

        NSArray<NSString *> *logicClasses = @[@"BrandDirectlyOperateContactLogic", @"WCBrandDirectlyOperateContactLogic"];
        for (NSString *className in logicClasses) {
            Class logicClass = NSClassFromString(className);
            if (!logicClass) continue;

            NSMutableArray *targets = [NSMutableArray array];
            YZAddUniqueTarget(targets, [YZWCRuntime getService:className]);
            YZAddUniqueTarget(targets, YZCallNoArgSelector(logicClass, @"sharedInstance"));
            YZAddUniqueTarget(targets, YZCallNoArgSelector(logicClass, @"defaultLogic"));
            YZAddUniqueTarget(targets, [[logicClass alloc] init]);

            for (id target in targets) {
                for (id argument in argumentCandidates) {
                    NSDictionary *context = @{@"scene": scene, @"fromScene": scene};
                    if (YZInvokeSelectorWithArguments(target, @"tryAddBrandContact:context:", @[argument, context])) {
                        NSLog(@"[小杳知] followBrand hit %@ tryAddBrandContact:context:", className);
                        return YES;
                    }
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
        return YZSearchBrandContactFromServer(contactMgr, brandUserName);
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

+ (BOOL)presentController:(UIViewController *)controller fromViewController:(UIViewController *)viewController {
    if (!controller) return NO;

    UIViewController *presenter = viewController ?: [self topMostViewController];
    if (YZShouldDismissBeforePresenting(presenter)) {
        void (^showController)(void) = ^{
            UIViewController *topVC = [self topMostViewController];
            UINavigationController *nav = YZPreferredPushNavigationController(topVC);
            if (nav) {
                [nav pushViewController:controller animated:YES];
            } else if (topVC) {
                [topVC presentViewController:controller animated:YES completion:nil];
            }
        };

        SEL customDismissSel = NSSelectorFromString(@"dismissAnimatedWithCompletion:");
        if ([presenter respondsToSelector:customDismissSel]) {
            ((void (*)(id, SEL, void (^)(void)))objc_msgSend)(presenter, customDismissSel, showController);
        } else {
            [presenter dismissViewControllerAnimated:YES completion:showController];
        }
        return YES;
    }

    UINavigationController *pushNav = YZPreferredPushNavigationController(viewController);
    if (pushNav) {
        [pushNav pushViewController:controller animated:YES];
        return YES;
    }

    if (!presenter) return NO;

    UINavigationController *nav = YZNavigationControllerFromViewController(presenter);
    if (nav) {
        [nav pushViewController:controller animated:YES];
    } else {
        [presenter presentViewController:controller animated:YES completion:nil];
    }
    return YES;
}

+ (BOOL)openBrandWebProfileFromViewController:(UIViewController *)viewController {
    NSURL *url = [NSURL URLWithString:kYZOfficialAccountProfileURL];
    if (!url) return NO;

    if (YZShouldDismissBeforePresenting(viewController)) {
        __block BOOL opened = NO;
        void (^openURL)(void) = ^{
            opened = YZOpenURLThroughWeChatRouter(url, [self topMostViewController]);
        };

        SEL customDismissSel = NSSelectorFromString(@"dismissAnimatedWithCompletion:");
        if ([viewController respondsToSelector:customDismissSel]) {
            ((void (*)(id, SEL, void (^)(void)))objc_msgSend)(viewController, customDismissSel, openURL);
            return opened;
        }

        [viewController dismissViewControllerAnimated:YES completion:^{
            if (!YZOpenURLThroughWeChatRouter(url, [self topMostViewController])) {
                UIPasteboard.generalPasteboard.string = @"杳知爱吃米饭";
            }
        }];
        return YES;
    }

    return YZOpenURLThroughWeChatRouter(url, viewController ?: [self topMostViewController]);
}

+ (BOOL)openBrandProfile:(NSString *)brandUserName fromViewController:(UIViewController *)viewController {
    if (brandUserName.length == 0) return NO;

    if ([brandUserName isEqualToString:kYZOfficialAccountUserName]) {
        return [self openBrandWebProfileFromViewController:viewController];
    }
    return NO;
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
