#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const kYZGameCheatEnabledKey = @"Xiaoyaozhi_RPSDiceEnabled";

static BOOL YZGameCheatEnabled(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:kYZGameCheatEnabledKey];
}

static UIViewController *YZGameTopViewController(void) {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow && window.rootViewController) {
                keyWindow = window;
                break;
            }
            if (!keyWindow && window.rootViewController) keyWindow = window;
        }
        if (keyWindow) break;
    }

    UIViewController *top = keyWindow.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if ([top isKindOfClass:UINavigationController.class]) {
        top = ((UINavigationController *)top).visibleViewController ?: top;
    }
    if ([top isKindOfClass:UITabBarController.class]) {
        top = ((UITabBarController *)top).selectedViewController ?: top;
    }
    return top;
}

static void YZSetGameResult(id msgWrap, NSInteger content) {
    if (!msgWrap) return;

    SEL setContentSel = NSSelectorFromString(@"setM_uiGameContent:");
    if ([msgWrap respondsToSelector:setContentSel]) {
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(msgWrap, setContentSel, (unsigned int)content);
    }

    Class gameController = NSClassFromString(@"GameController");
    SEL md5Sel = NSSelectorFromString(@"getMD5ByGameContent:");
    if (gameController && [gameController respondsToSelector:md5Sel]) {
        NSString *md5 = ((NSString *(*)(id, SEL, unsigned int))objc_msgSend)(gameController, md5Sel, (unsigned int)content);
        if (md5.length > 0) {
            SEL setMD5Sel = NSSelectorFromString(@"setM_nsEmoticonMD5:");
            if ([msgWrap respondsToSelector:setMD5Sel]) {
                ((void (*)(id, SEL, NSString *))objc_msgSend)(msgWrap, setMD5Sel, md5);
            }
        }
    }
}

%hook CMessageMgr

- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(id)msgWrap {
    if (!YZGameCheatEnabled() || !msgWrap) {
        %orig;
        return;
    }

    SEL messageTypeSel = NSSelectorFromString(@"m_uiMessageType");
    SEL gameTypeSel = NSSelectorFromString(@"m_uiGameType");
    if (![msgWrap respondsToSelector:messageTypeSel] || ![msgWrap respondsToSelector:gameTypeSel]) {
        %orig;
        return;
    }

    unsigned int messageType = ((unsigned int (*)(id, SEL))objc_msgSend)(msgWrap, messageTypeSel);
    unsigned int gameType = ((unsigned int (*)(id, SEL))objc_msgSend)(msgWrap, gameTypeSel);
    if (messageType != 47 || (gameType != 1 && gameType != 2)) {
        %orig;
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"小游戏"
                                                                   message:(gameType == 1 ? @"请选择出拳" : @"请选择骰子点数")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSString *> *titles = gameType == 1 ? @[@"剪刀", @"石头", @"布"] : @[@"1", @"2", @"3", @"4", @"5", @"6"];
    NSInteger offset = gameType == 1 ? 1 : 4;

    for (NSInteger i = 0; i < titles.count; i++) {
        NSInteger content = i + offset;
        UIAlertAction *action = [UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
            YZSetGameResult(msgWrap, content);
            %orig(msg, msgWrap);
        }];
        [alert addAction:action];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *top = YZGameTopViewController();
    if (!top) {
        %orig;
        return;
    }

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = top.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 1, 1);
        popover.permittedArrowDirections = 0;
    }

    [top presentViewController:alert animated:YES completion:nil];
}

%end
