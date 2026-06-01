#import <Foundation/Foundation.h>

// 隐私守卫 - 运行时隐私合规检查和访问拦截
@interface YZPrivacyGuard : NSObject

/// 执行隐私合规检查（返回不符合的权限列表）
+ (NSArray<NSString *> *)performPrivacyAudit;

/// 检查是否尝试访问禁止的 API
+ (BOOL)isPrivacySensitiveAPI:(NSString *)apiName;

/// 记录隐私访问（用于审计）
+ (void)logPrivacyAccess:(NSString *)apiName;

/// 生成隐私报告（JSON 格式）
+ (NSString *)generatePrivacyReport;

@end
