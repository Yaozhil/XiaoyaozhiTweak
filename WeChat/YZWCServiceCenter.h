#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 微信 MMServiceCenter 桥接 - 提供通用服务访问
@interface YZWCServiceCenter : NSObject

/// 获取联系人管理器
+ (id)getContactManager;

/// 获取会话管理器
+ (id)getMessageManager;

/// 获取当前登录用户名
+ (NSString *)getCurrentUserName;

/// 检查是否已登录微信
+ (BOOL)isLoggedIn;

/// 检查公众号是否已关注
+ (BOOL)isBrandFollowing:(NSString *)brandUserName;

/// 关注公众号
+ (BOOL)followBrand:(NSString *)brandUserName;

/// 打开公众号资料页，供用户手动关注
+ (BOOL)openBrandProfile:(NSString *)brandUserName fromViewController:(UIViewController *)viewController;

/// 获取当前登录用户的微信头像（UIImage）
+ (UIImage *)getSelfAvatar;

/// 后台刷新当前登录用户头像
+ (void)fetchSelfAvatarWithCompletion:(void(^)(UIImage *avatar))completion;

/// 缓存从微信界面捕获到的当前用户头像
+ (void)rememberPossibleSelfAvatar:(UIImage *)avatar;

/// 获取当前登录用户的昵称
+ (NSString *)getSelfNickname;

/// 获取当前登录用户的微信号
+ (NSString *)getSelfWeChatID;

#pragma mark - 系统与应用信息检测

/// 设备型号（如 iPhone 17 Pro）
+ (NSString *)getDeviceModel;

/// 系统版本（如 26.0）
+ (NSString *)getSystemVersion;

/// 微信包名
+ (NSString *)getBundleIdentifier;

/// 微信版本号
+ (NSString *)getWeChatVersion;

/// 获取WXID（微信内部ID，如无法获取返回未知）
+ (NSString *)getWXID;

#pragma mark - 签名证书检测

/// 签名证书到期时间字符串
+ (NSString *)getCertificateExpirationDate;

/// 证书剩余天数，负数表示已过期
+ (NSInteger)getCertificateRemainingDays;

/// 证书类型（企业签名 / 开发者签名 / Ad-Hoc / 未知）
+ (NSString *)getCertificateType;

/// 证书团队名称
+ (NSString *)getCertificateTeamName;

/// 证书名称
+ (NSString *)getCertificateName;

/// 证书关联的 App ID
+ (NSString *)getCertificateAppID;

/// Provisioning Profile 创建日期
+ (NSString *)getProfileCreationDate;

/// 设备 UDID 是否在证书注册列表中（仅开发者签名有意义）
+ (BOOL)isDeviceUDIDInProfile;

/// 证书剩余天数，负数表示已过期
+ (NSInteger)getCertificateRemainingDays;

#pragma mark - 权限信息（Entitlements 全量检测）

/// 返回所有检测到的 entitlements 字典: key=权限名称(中文), value=@YES/@NO
+ (NSDictionary<NSString *, NSNumber *> *)getAllEntitlements;

/// 检查单个 entitlement key 是否存在
+ (BOOL)hasEntitlementKey:(NSString *)entitlementKey;

#pragma mark - 设备信息

/// 获取 ProvisionedDevices 中所有注册的 UDID 列表
+ (NSArray<NSString *> *)getProvisionedDeviceUDIDs;

/// ProvisionedDevices 注册的设备数量
+ (NSInteger)getProvisionedDeviceCount;

@end
