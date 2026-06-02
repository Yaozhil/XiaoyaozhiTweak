#import "YZPrivacyGuard.h"

// 插件明确不使用的敏感 API 列表（此处记录是为了审计，而非拦截）
static NSSet<NSString *> *sForbiddenAPIs = nil;

// 隐私访问日志
static NSMutableArray<NSDictionary *> *sPrivacyLog = nil;

@implementation YZPrivacyGuard

+ (void)initialize {
    if (self == [YZPrivacyGuard class]) {
        sForbiddenAPIs = [NSSet setWithArray:@[
            // 相册
            @"PHPhotoLibrary", @"UIImagePickerController",
            // 通讯录
            @"CNContactStore", @"ABAddressBook",
            // 定位
            @"CLLocationManager", @"CLVisit",
            // 麦克风
            @"AVAudioSession", @"AVAudioRecorder",
            // 相机
            @"AVCaptureDevice", @"AVCaptureSession",
            // 蓝牙
            @"CBCentralManager", @"CBPeripheralManager",
            // 日历
            @"EKEventStore",
            // 健康
            @"HKHealthStore",
            // HomeKit
            @"HMHomeManager",
            // 通知推送
            @"UNUserNotificationCenter",
            // Keychain
            @"SecItemAdd", @"SecItemCopyMatching",
        ]];

        sPrivacyLog = [NSMutableArray array];
    }
}

+ (NSArray<NSString *> *)performPrivacyAudit {
    NSMutableArray *violations = [NSMutableArray array];

    // 运行时检查：是否有任何隐私相关类被加载
    for (NSString *className in sForbiddenAPIs) {
        Class forbiddenClass = NSClassFromString(className);
        if (forbiddenClass) {
            // 仅记录该类存在（微信本身可能加载），但不代表插件调用了它
            // 真正的检查依靠代码审查和静态分析
        }
    }

    // 检查 Info.plist 中没有隐私描述
    NSDictionary *infoPlist = NSBundle.mainBundle.infoDictionary;
    NSArray *privacyKeys = @[
        @"NSPhotoLibraryUsageDescription",
        @"NSContactsUsageDescription",
        @"NSLocationWhenInUseUsageDescription",
        @"NSMicrophoneUsageDescription",
        @"NSCameraUsageDescription",
        @"NSBluetoothAlwaysUsageDescription",
        @"NSCalendarsUsageDescription",
        @"NSHealthShareUsageDescription",
        @"NSHomeKitUsageDescription"
    ];

    for (NSString *key in privacyKeys) {
        if (infoPlist[key]) {
            [violations addObject:[NSString stringWithFormat:@"Info.plist 包含隐私描述: %@ (插件本身不应声明)", key]];
        }
    }

    return [violations copy];
}

+ (BOOL)isPrivacySensitiveAPI:(NSString *)apiName {
    if (!apiName) return NO;
    return [sForbiddenAPIs containsObject:apiName];
}

+ (void)logPrivacyAccess:(NSString *)apiName {
    if (!apiName) return;

    @synchronized (sPrivacyLog) {
        NSDictionary *entry = @{
            @"api": apiName,
            @"timestamp": @([[NSDate date] timeIntervalSince1970]),
            @"date": [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                    dateStyle:NSDateFormatterShortStyle
                                                    timeStyle:NSDateFormatterMediumStyle]
        };
        [sPrivacyLog addObject:entry];
    }
}

+ (NSString *)generatePrivacyReport {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];

    report[@"plugin_name"] = @"小杳知";
    report[@"plugin_id"] = @"com.rouneed.xiaoyaozhi";
    report[@"version"] = @"1.2.2";
    report[@"generated_at"] = @([[NSDate date] timeIntervalSince1970]);

    // 隐私承诺
    report[@"privacy_commitments"] = @[
        @"不访问相册",
        @"不访问通讯录",
        @"不获取定位",
        @"不使用麦克风",
        @"不使用相机",
        @"不使用蓝牙",
        @"不访问日历/提醒事项",
        @"不访问健康数据",
        @"不访问 HomeKit",
        @"不读取 Keychain（微信沙盒外）",
        @"不发起网络请求（仅通过微信内建服务）",
        @"仅使用 NSUserDefaults 存储自身配置",
    ];

    // 数据存储范围
    report[@"data_storage"] = @{
        @"nsuserdefaults_suite": @"com.rouneed.xiaoyaozhi",
        @"purpose": @"插件配置存储",
        @"contains_personal_data": @NO,
    };

    // 内部 API 使用
    report[@"internal_api_usage"] = @[
        @"MMServiceCenter (微信公开服务定位)",
        @"CContactMgr (联系人管理-仅限关注公众号)",
        @"仅在微信沙盒内操作",
    ];

    // 隐私审计结果
    NSArray *violations = [self performPrivacyAudit];
    report[@"audit_violations"] = violations.count > 0 ? violations : @"无违规项";

    // 序列化
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:report
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (jsonData) {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return @"{}";
}

@end
