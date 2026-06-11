#import "YZGlassSheetController.h"
#import "YZGlassOverlayView.h"
#import "YZAnimator.h"
#import "YZEnvironmentDetector.h"
#import "YZWCServiceCenter.h"
#import "YZConfigManager.h"
#import "YZPluginLifecycle.h"
#import "YZCrashGuard.h"
#import "YZRuntimeLogger.h"

#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

extern UIImage *YZEmbeddedFollowIconImage(void);

static NSString *const kGHUserName = @"gh_5a0621af5c7d";
static NSArray<NSString *> *YZPriorityEntitlementNames(void) {
    return @[@"应用组", @"WiFi 访问", @"扩展虚拟地址", @"推送通知", @"钥匙串访问", @"增加内存限制"];
}

@interface YZGlassSheetController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *statusBarBg;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *infoButton;
@property (nonatomic, strong) UILabel *navTitle;
@property (nonatomic, strong) UIView *navBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UIView *avatarShell;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIView *followCard;
@property (nonatomic, strong) UILabel *followStatusLabel;
@property (nonatomic, strong) UIView *followDot;
@property (nonatomic, strong) UIView *followIconView;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer *internalBackGesture;
@property (nonatomic, assign) BOOL isFollowed;
@property (nonatomic, assign) NSInteger followState;
@property (nonatomic, assign) BOOL isPresented;
@property (nonatomic, assign) NSInteger currentPage; // 0=main, 1=account, 2=all permissions
@property (nonatomic, assign) BOOL savedInteractivePopEnabled;
@property (nonatomic, assign) BOOL hasSavedInteractivePopState;
@end

@implementation YZGlassSheetController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentPage = 0;
        _followState = -1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [YZRuntimeLogger logEvent:@"sheet.view_did_load"];
    self.view.backgroundColor = [UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:1.0]; // #F2F2F7
    [self buildMainUI];
    [self refreshAvatar];
    [self refreshFollowStatus];
    [self scheduleAvatarRetryIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self configureHostNavigation];
    [self updateBackButtonVisibility];
    [self updateInteractivePopGesture];
    if (!self.isPresented) {
        self.isPresented = YES;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self restoreInteractivePopGesture];
}

- (void)dealloc {
    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
    [self.view.layer removeAllAnimations];
    [self.followCard.layer removeAllAnimations];
    [self.followDot.layer removeAllAnimations];
    [self restoreInteractivePopGesture];
}

#pragma mark - Main UI

- (void)buildMainUI {
    YZEnvironmentDetector *env = [YZEnvironmentDetector shared];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat topSafe = env.safeAreaTopInset;
    CGFloat bottomSafe = MAX(env.safeAreaBottomInset, 18);

    // 状态栏背景
    self.statusBarBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, topSafe)];
    self.statusBarBg.backgroundColor = [UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:1.0];
    [self.view addSubview:self.statusBarBg];

    // 导航栏
    CGFloat navY = topSafe;
    CGFloat navH = 52;
    self.navBar = [[UIView alloc] initWithFrame:CGRectMake(0, navY, w, navH)];
    self.navBar.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.navBar];

    self.internalBackGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleInternalBackGesture:)];
    self.internalBackGesture.edges = UIRectEdgeLeft;
    self.internalBackGesture.enabled = NO;
    [self.view addGestureRecognizer:self.internalBackGesture];

    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.backButton.frame = CGRectMake(8, 10, 32, 32);
    [self.backButton setTitle:@"‹" forState:UIControlStateNormal];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightLight];
    self.backButton.tintColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
    [self.backButton addTarget:self action:@selector(didTapBack) forControlEvents:UIControlEventTouchUpInside];
    self.backButton.hidden = ![self shouldShowRootBackButton];
    [self.navBar addSubview:self.backButton];

    self.navTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w - 120, navH)];
    self.navTitle.center = CGPointMake(w / 2.0, navH / 2.0);
    self.navTitle.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.navTitle.textAlignment = NSTextAlignmentCenter;
    self.navTitle.hidden = YES;
    [self.navBar addSubview:self.navTitle];

    self.infoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.infoButton.frame = CGRectMake(w - 48, 8, 36, 36);
    [self.infoButton setTitle:@"ⓘ" forState:UIControlStateNormal];
    self.infoButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
    self.infoButton.tintColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
    [self.navBar addSubview:self.infoButton];

    // TableView
    CGFloat tableY = navY + navH;
    CGFloat bottomOverlayH = 76 + bottomSafe;
    CGFloat tableH = MAX(44, h - tableY);
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, w, tableH) style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = self.view.backgroundColor;
    self.tableView.opaque = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, bottomOverlayH + 10, 0);
    [self.view addSubview:self.tableView];

    // Header
    [self buildTableHeader:w];
    self.tableView.tableHeaderView = self.headerView;

    // 底部关注栏
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, h - bottomOverlayH, w, bottomOverlayH)];
    self.bottomBar.backgroundColor = [UIColor clearColor];
    self.bottomBar.clipsToBounds = NO;
    [self.view addSubview:self.bottomBar];

    CAGradientLayer *bottomFade = [CAGradientLayer layer];
    bottomFade.frame = self.bottomBar.bounds;
    bottomFade.colors = @[
        (__bridge id)[UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:0.58].CGColor,
        (__bridge id)[UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:0.92].CGColor
    ];
    bottomFade.locations = @[@0.0, @0.55, @1.0];
    [self.bottomBar.layer addSublayer:bottomFade];

    CGFloat cardW = w - 36;
    self.followCard = [[UIView alloc] initWithFrame:CGRectMake(18, 24, cardW, 48)];
    self.followCard.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    self.followCard.layer.cornerRadius = 18;
    self.followCard.layer.borderWidth = 0.5;
    self.followCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
    self.followCard.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.08].CGColor;
    self.followCard.layer.shadowOpacity = 1.0;
    self.followCard.layer.shadowRadius = 20;
    self.followCard.layer.shadowOffset = CGSizeMake(0, 8);
    self.followCard.clipsToBounds = NO;
    self.followCard.userInteractionEnabled = YES;

    UITapGestureRecognizer *followTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFollowTap)];
    [self.followCard addGestureRecognizer:followTap];
    [self.bottomBar addSubview:self.followCard];

    // 行内元素
    self.followIconView = [self followIconViewWithFrame:CGRectMake(18, 11, 26, 26)];
    [self.followCard addSubview:self.followIconView];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(54, 14, cardW - 152, 20)];
    label.text = @"小杳知公众号";
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    [self.followCard addSubview:label];

    self.followDot = [[UIView alloc] initWithFrame:CGRectMake(cardW - 84, 21, 6, 6)];
    self.followDot.layer.cornerRadius = 3;
    [self.followCard addSubview:self.followDot];

    self.followStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(cardW - 74, 14, 50, 20)];
    self.followStatusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.followStatusLabel.textAlignment = NSTextAlignmentRight;
    [self.followCard addSubview:self.followStatusLabel];
}

- (UIView *)followIconViewWithFrame:(CGRect)frame {
    UIView *icon = [[UIView alloc] initWithFrame:frame];
    icon.backgroundColor = UIColor.clearColor;
    icon.layer.cornerRadius = 8;
    icon.clipsToBounds = YES;

    UIImage *customIcon = YZEmbeddedFollowIconImage();
    if (!customIcon) {
        NSArray *paths = @[
            @"/var/jb/Library/Application Support/XiaoyaozhiTweak/follow_icon.png",
            @"/Library/Application Support/XiaoyaozhiTweak/follow_icon.png",
        ];
        for (NSString *path in paths) {
            customIcon = [UIImage imageWithContentsOfFile:path];
            if (customIcon) break;
        }
    }

    if (customIcon) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:icon.bounds];
        imageView.image = customIcon;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = UIColor.clearColor;
        imageView.clipsToBounds = YES;
        [icon addSubview:imageView];
        return icon;
    }

    // 兜底：使用内嵌图标
    UIImage *followIcon = YZEmbeddedFollowIconImage();
    if (followIcon) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:icon.bounds];
        imageView.image = followIcon;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        [icon addSubview:imageView];
    } else {
        icon.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:0.12];
        icon.layer.cornerRadius = 9;
        UILabel *spark = [[UILabel alloc] initWithFrame:icon.bounds];
        spark.text = @"杳";
        spark.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        spark.textAlignment = NSTextAlignmentCenter;
        spark.textColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
        [icon addSubview:spark];
    }

    return icon;
}

- (void)buildTableHeader:(CGFloat)w {
    CGFloat headerH = 238;
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, headerH)];

    CGFloat avatarSize = 78;
    CGFloat shellSize = 88;
    CGFloat shellX = (w - shellSize) / 2.0;
    CGFloat shellY = 31;

    self.avatarShell = [[UIView alloc] initWithFrame:CGRectMake(shellX, shellY, shellSize, shellSize)];
    self.avatarShell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    self.avatarShell.layer.cornerRadius = 26;
    self.avatarShell.clipsToBounds = YES;
    [self.headerView addSubview:self.avatarShell];

    self.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, avatarSize, avatarSize)];
    self.avatarView.layer.cornerRadius = 22;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.backgroundColor = [UIColor colorWithRed:0.86 green:0.93 blue:1.0 alpha:1.0];

    [self.avatarShell addSubview:self.avatarView];

    // 名称
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, shellY + shellSize + 14, w, 34)];
    self.nameLabel.text = @"小杳知";
    self.nameLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    [self.headerView addSubview:self.nameLabel];

    // 版本
    self.versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, shellY + shellSize + 51, w, 22)];
    self.versionLabel.text = [NSString stringWithFormat:@"Version: %@", [YZPluginLifecycle sharedInstance].pluginVersion];
    self.versionLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    self.versionLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
    [self.headerView addSubview:self.versionLabel];
}

#pragma mark - TableView

static NSDictionary *sEntitlementsCache = nil;
static NSArray<NSString *> *sOrderedEntitlementNamesCache = nil;

- (UIColor *)tableCardColor {
    return [UIColor colorWithRed:0.988 green:0.990 blue:1.0 alpha:1.0];
}

- (NSArray<NSString *> *)orderedEntitlementNames {
    if (sOrderedEntitlementNamesCache) return sOrderedEntitlementNamesCache;
    if (!sEntitlementsCache) sEntitlementsCache = [YZWCServiceCenter getAllEntitlements];

    NSArray<NSString *> *priority = YZPriorityEntitlementNames();
    NSArray<NSString *> *all = [sEntitlementsCache.allKeys sortedArrayUsingSelector:@selector(compare:)];

    NSMutableArray<NSString *> *enabledPri = [NSMutableArray array];
    NSMutableArray<NSString *> *enabledOth = [NSMutableArray array];
    NSMutableArray<NSString *> *disabledPri = [NSMutableArray array];
    NSMutableArray<NSString *> *disabledOth = [NSMutableArray array];

    for (NSString *name in priority) {
        if (sEntitlementsCache[name]) {
            if ([sEntitlementsCache[name] boolValue]) [enabledPri addObject:name];
            else [disabledPri addObject:name];
        }
    }
    for (NSString *name in all) {
        if ([priority containsObject:name]) continue;
        if ([sEntitlementsCache[name] boolValue]) [enabledOth addObject:name];
        else [disabledOth addObject:name];
    }

    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    [ordered addObjectsFromArray:enabledPri];
    [ordered addObjectsFromArray:enabledOth];
    [ordered addObjectsFromArray:disabledPri];
    [ordered addObjectsFromArray:disabledOth];

    sOrderedEntitlementNamesCache = [ordered copy];
    return sOrderedEntitlementNamesCache;
}

- (UIView *)statusDotViewWithEnabled:(BOOL)enabled {
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 48)];
    c.backgroundColor = UIColor.clearColor;
    UIView *d = [[UIView alloc] initWithFrame:CGRectMake(6, 19, 10, 10)];
    d.layer.cornerRadius = 5;
    d.backgroundColor = enabled ? [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0]
                                 : [UIColor colorWithWhite:0.82 alpha:1.0];
    [c addSubview:d];
    return c;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    if (self.currentPage == 0) return 1;
    if (self.currentPage == 2) return 1;
    return 5; // 用户信息 应用信息 证书信息 权限信息 查看全部
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    if (self.currentPage == 0) return 3;
    if (self.currentPage == 2) return [self orderedEntitlementNames].count;
    switch (sec) {
        case 0: return 2;  // 用户信息（2行）
        case 1: return 5;  // 应用信息
        case 2: return 1;  // 证书到期
        case 3: return 6;  // 核心权限
        case 4: return 1;  // 查看全部权限
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)sec {
    if (self.currentPage == 1 && sec == 4) return 14;
    return 44;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)sec {
    return 8;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)sec {
    if (self.currentPage == 0) return nil;
    if (self.currentPage == 2) return @"全部权限";
    if (sec == 4) return nil;
    return @[@"用户信息", @"应用信息", @"证书信息", @"权限信息"][sec];
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"cell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
        cell.backgroundColor = [self tableCardColor];
        cell.contentView.backgroundColor = cell.backgroundColor;
        cell.opaque = YES;
        cell.contentView.opaque = YES;
        cell.textLabel.font = [UIFont systemFontOfSize:17];
        cell.textLabel.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIView *selectedBackgroundView = [[UIView alloc] init];
        selectedBackgroundView.backgroundColor = [self tableCardColor];
        cell.selectedBackgroundView = selectedBackgroundView;
    }
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
    cell.detailTextLabel.text = nil;

    // ====== 主菜单 ======
    if (self.currentPage == 0) {
        cell.textLabel.text = @[@"到期信息", @"运行日志", @"投喂一下"][ip.row];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        cell.detailTextLabel.text = @"";
        cell.accessoryView = [self arrowView];
        return cell;
    }

    // ====== 全部权限子页 ======
    if (self.currentPage == 2) {
        return [self entitlementCell:cell atRow:ip.row section:ip.section];
    }

    // ====== 到期信息页 ======
    cell.accessoryView = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];

    switch (ip.section) {
        case 0: return [self userInfoCell:cell atRow:ip.row];
        case 1: return [self appInfoCell:cell atRow:ip.row];
        case 2: return [self certInfoCell:cell atRow:ip.row];
        case 3: return [self permInfoCell:cell atRow:ip.row tv:tv];
        case 4: return [self permissionMoreCell:cell];
    }
    return cell;
}

- (UITableViewCell *)userInfoCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    switch (row) {
        case 0: cell.textLabel.text = @"微信名"; cell.detailTextLabel.text = [YZWCServiceCenter getSelfNickname] ?: @"无法检测"; break;
        case 1: cell.textLabel.text = @"微信号"; cell.detailTextLabel.text = [YZWCServiceCenter getSelfWeChatID] ?: @"无法检测"; break;
    }
    return cell;
}

- (UITableViewCell *)appInfoCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    switch (row) {
        case 0: { NSString *n = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"]; cell.textLabel.text = @"应用名称"; cell.detailTextLabel.text = n.length > 0 ? n : @"无法检测"; break; }
        case 1: cell.textLabel.text = @"系统版本"; cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", [YZWCServiceCenter getSystemVersion]]; break;
        case 2: cell.textLabel.text = @"微信包名"; cell.detailTextLabel.text = [YZWCServiceCenter getBundleIdentifier]; break;
        case 3: cell.textLabel.text = @"微信版本"; cell.detailTextLabel.text = [YZWCServiceCenter getWeChatVersion]; break;
        case 4: cell.textLabel.text = @"设备标识"; cell.detailTextLabel.text = [YZWCServiceCenter getDeviceModel]; break;
    }
    return cell;
}

- (UITableViewCell *)certInfoCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    NSString *expDate = [YZWCServiceCenter getCertificateExpirationDate];
    NSInteger days = [YZWCServiceCenter getCertificateRemainingDays];

    cell.textLabel.text = @"证书到期";
    cell.accessoryView = nil;

    if (days == NSIntegerMin) {
        cell.detailTextLabel.text = expDate;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
        return cell;
    }

    NSString *badge;
    UIColor *badgeColor;
    if (days < 0) {
        badge = @"已过期";
        badgeColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    } else if (days <= 7) {
        badge = [NSString stringWithFormat:@"剩余 %ld天", (long)days];
        badgeColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    } else if (days <= 30) {
        badge = [NSString stringWithFormat:@"剩余 %ld天", (long)days];
        badgeColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0];
    } else {
        badge = [NSString stringWithFormat:@"剩余 %ld天", (long)days];
        badgeColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    }

    NSString *full = [NSString stringWithFormat:@"%@  ·  %@", expDate, badge];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:15],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.56 alpha:1.0]
    }];
    NSRange r = [full rangeOfString:badge];
    if (r.location != NSNotFound) {
        [attr addAttribute:NSForegroundColorAttributeName value:badgeColor range:r];
        [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium] range:r];
    }
    cell.detailTextLabel.attributedText = attr;

    return cell;
}

- (UITableViewCell *)permInfoCell:(UITableViewCell *)cell atRow:(NSInteger)row tv:(UITableView *)tv {
    // 核心 6 项
    NSArray *core = YZPriorityEntitlementNames();
    if (!sEntitlementsCache) sEntitlementsCache = [YZWCServiceCenter getAllEntitlements];
    BOOL on = [sEntitlementsCache[core[row]] boolValue];
    cell.textLabel.text = core[row];
    cell.detailTextLabel.text = @"";
    cell.accessoryView = [self statusDotViewWithEnabled:on];
    return cell;
}

- (UITableViewCell *)permissionMoreCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"查看全部权限";
    cell.detailTextLabel.text = @"";
    cell.accessoryView = [self arrowView];
    return cell;
}

// 全部权限子页
- (UITableViewCell *)entitlementCell:(UITableViewCell *)cell atRow:(NSInteger)row section:(NSInteger)sec {
    NSArray *all = [self orderedEntitlementNames];
    if (row >= all.count) { cell.textLabel.text = @""; return cell; }
    NSString *name = all[row];
    BOOL on = [sEntitlementsCache[name] boolValue];

    cell.textLabel.text = name;
    cell.detailTextLabel.text = @"";
    cell.accessoryView = [self statusDotViewWithEnabled:on];
    return cell;
}

#pragma mark - Arrow / Selection

- (UIView *)arrowView {
    UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 48)];
    c.backgroundColor = UIColor.clearColor;
    c.userInteractionEnabled = NO;
    UIColor *muted = [UIColor colorWithWhite:0.72 alpha:1.0];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(10, 14, 12, 20)];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tintColor = muted;
    iv.image = [UIImage systemImageNamed:@"chevron.right" withConfiguration:cfg];
    [c addSubview:iv];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (self.currentPage == 0) {
        if (ip.row == 0) [self goToAccountInfo];
        else if (ip.row == 1) {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [gen impactOccurred];
            [self copyRuntimeFeedback];
        }
        else if (ip.row == 2) [self showRewardSheet];
        return;
    }
    // 用户信息行可点击复制
    if (self.currentPage == 1 && ip.section == 0) {
        NSString *label = ip.row == 0 ? @"微信名" : @"微信号";
        UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
        NSString *value = cell.detailTextLabel.text;
        if (value.length > 0 && ![value hasPrefix:@"无法检测"]) {
            UIPasteboard.generalPasteboard.string = value;
            // 播放系统复制反馈音效
            AudioServicesPlaySystemSound(1104); // 轻触反馈音
            [self showToast:[NSString stringWithFormat:@"已复制%@：%@", label, value]];
        }
        return;
    }
    if (self.currentPage == 1 && ip.section == 4 && ip.row == 0) {
        [self goToAllPermissions];
    }
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
    cell.backgroundColor = [self tableCardColor];
    cell.contentView.backgroundColor = cell.backgroundColor;
    cell.opaque = YES;
    cell.contentView.opaque = YES;
    cell.layer.drawsAsynchronously = YES;
    cell.layer.shouldRasterize = NO;
    cell.layer.borderWidth = 0.5;
    cell.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.82].CGColor;
    NSInteger rows = [self tableView:tv numberOfRowsInSection:ip.section];
    if (rows == 1) {
        cell.layer.cornerRadius = 18; cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else if (ip.row == 0) {
        cell.layer.cornerRadius = 18; cell.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    } else if (ip.row == rows - 1) {
        cell.layer.cornerRadius = 18; cell.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else {
        cell.layer.cornerRadius = 0; cell.layer.maskedCorners = 0;
    }
    cell.clipsToBounds = YES;
}

#pragma mark - Navigation

- (void)configureHostNavigation {
    self.navigationItem.leftBarButtonItem = nil;
    [self.navigationItem setHidesBackButton:YES animated:NO];
}

- (void)updateInteractivePopGesture {
    UIGestureRecognizer *gesture = self.navigationController.interactivePopGestureRecognizer;
    if (gesture) {
        if (!self.hasSavedInteractivePopState) {
            self.savedInteractivePopEnabled = gesture.enabled;
            self.hasSavedInteractivePopState = YES;
        }
        gesture.enabled = (self.currentPage == 0 && [self shouldShowRootBackButton]) ? self.savedInteractivePopEnabled : NO;
    }
    self.internalBackGesture.enabled = (self.currentPage != 0);
}

- (void)restoreInteractivePopGesture {
    UIGestureRecognizer *gesture = self.navigationController.interactivePopGestureRecognizer;
    if (!gesture || !self.hasSavedInteractivePopState) return;
    gesture.enabled = self.savedInteractivePopEnabled;
    self.hasSavedInteractivePopState = NO;
}

- (void)handleInternalBackGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    if (translation.x > 44 || velocity.x > 360) {
        [self didTapBack];
    }
}

- (BOOL)shouldShowRootBackButton {
    UINavigationController *navigationController = self.navigationController;
    return navigationController && navigationController.viewControllers.firstObject != self;
}

- (void)updateBackButtonVisibility {
    self.backButton.hidden = (self.currentPage == 0 && ![self shouldShowRootBackButton]);
}

- (CGPoint)tableTopOffset {
    CGFloat topInset = 0;
    if (@available(iOS 11.0, *)) {
        topInset = self.tableView.adjustedContentInset.top;
    } else {
        topInset = self.tableView.contentInset.top;
    }
    return CGPointMake(0, -topInset);
}

- (void)reloadTableAtTop {
    CGPoint topOffset = [self tableTopOffset];
    [UIView performWithoutAnimation:^{
        [self.tableView setContentOffset:topOffset animated:NO];
        [self.tableView reloadData];
        [self.tableView setContentOffset:topOffset animated:NO];
    }];
}

- (void)goToAccountInfo {
    self.currentPage = 1;
    sEntitlementsCache = nil; // 刷新缓存
    sOrderedEntitlementNamesCache = nil;
    [self updateBackButtonVisibility];
    [self updateInteractivePopGesture];
    self.navTitle.hidden = NO;
    self.navTitle.text = @"到期信息";
    self.infoButton.hidden = YES;
    [self reloadTableAtTop];
}

- (void)goToAllPermissions {
    self.currentPage = 2;
    sEntitlementsCache = nil;
    sOrderedEntitlementNamesCache = nil;
    [self updateInteractivePopGesture];
    self.navTitle.text = @"全部权限";
    [self reloadTableAtTop];
}

- (void)didTapBack {
    if (self.currentPage == 2) {
        self.currentPage = 1;
        [self updateInteractivePopGesture];
        self.navTitle.text = @"到期信息";
        [self reloadTableAtTop];
    } else if (self.currentPage == 1) {
        self.currentPage = 0;
        [self updateBackButtonVisibility];
        [self updateInteractivePopGesture];
        self.navTitle.hidden = YES;
        self.infoButton.hidden = NO;
        [self reloadTableAtTop];
    } else if (self.currentPage == 0 && [self shouldShowRootBackButton]) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Follow

- (BOOL)isCandidateAvatarImageView:(UIImageView *)imageView {
    if (!imageView || imageView == self.avatarView || !imageView.image) return NO;
    if (self.appIcon && imageView.image == self.appIcon) return NO;

    CGRect bounds = imageView.bounds;
    CGFloat minSide = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    CGFloat maxSide = MAX(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (minSide < 58 || maxSide > 132) return NO;

    CGSize imageSize = imageView.image.size;
    if (imageSize.width < 36 || imageSize.height < 36) return NO;
    CGFloat ratio = imageSize.width / MAX(imageSize.height, 1.0);
    if (ratio <= 0.75 || ratio >= 1.33) return NO;

    return [self imageLooksDetailedEnoughForAvatar:imageView.image];
}

- (BOOL)imageLooksDetailedEnoughForAvatar:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return NO;

    enum { sampleWidth = 12, sampleHeight = 12 };
    unsigned char pixels[sampleWidth * sampleHeight * 4] = {0};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, sampleWidth, sampleHeight, 8, sampleWidth * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return NO;

    CGContextDrawImage(context, CGRectMake(0, 0, sampleWidth, sampleHeight), cgImage);
    CGContextRelease(context);

    CGFloat lumaSum = 0;
    CGFloat lumaSquareSum = 0;
    NSUInteger opaqueCount = 0;
    for (size_t i = 0; i < sampleWidth * sampleHeight; i++) {
        CGFloat alpha = pixels[i * 4 + 3] / 255.0;
        if (alpha < 0.35) continue;
        CGFloat red = pixels[i * 4] / 255.0;
        CGFloat green = pixels[i * 4 + 1] / 255.0;
        CGFloat blue = pixels[i * 4 + 2] / 255.0;
        CGFloat luma = red * 0.299 + green * 0.587 + blue * 0.114;
        lumaSum += luma;
        lumaSquareSum += luma * luma;
        opaqueCount++;
    }

    if (opaqueCount < sampleWidth * sampleHeight * 0.55) return NO;
    CGFloat mean = lumaSum / MAX((CGFloat)opaqueCount, 1.0);
    CGFloat variance = lumaSquareSum / MAX((CGFloat)opaqueCount, 1.0) - mean * mean;
    return variance > 0.006;
}

- (UIImage *)avatarFromViewHierarchy:(UIView *)view bestSide:(CGFloat *)bestSide {
    if (!view || view.hidden || view.alpha < 0.05) return nil;

    UIImage *bestImage = nil;
    if ([view isKindOfClass:UIImageView.class]) {
        UIImageView *imageView = (UIImageView *)view;
        if ([self isCandidateAvatarImageView:imageView]) {
            CGFloat side = MIN(CGRectGetWidth(imageView.bounds), CGRectGetHeight(imageView.bounds));
            if (side > *bestSide) {
                *bestSide = side;
                bestImage = imageView.image;
            }
        }
    }

    for (UIView *subview in view.subviews) {
        UIImage *candidate = [self avatarFromViewHierarchy:subview bestSide:bestSide];
        if (candidate) bestImage = candidate;
    }
    return bestImage;
}

- (UIImage *)avatarFromWeChatNavigationStack {
    CGFloat bestSide = 0;
    UIImage *bestImage = nil;

    NSArray<UIViewController *> *controllers = self.navigationController.viewControllers ?: @[];
    for (UIViewController *controller in controllers) {
        if (controller == self || !controller.isViewLoaded) continue;
        NSString *className = NSStringFromClass(controller.class).lowercaseString;
        if ([className containsString:@"plugin"] || [className containsString:@"yzglass"]) continue;
        UIImage *candidate = [self avatarFromViewHierarchy:controller.view bestSide:&bestSide];
        if (candidate) bestImage = candidate;
    }

    return bestImage;
}

- (void)refreshFollowStatus {
    self.followState = [YZWCServiceCenter brandFollowState:kGHUserName];
    self.isFollowed = (self.followState == 1);
    [YZRuntimeLogger logEvent:@"sheet.follow_state" info:@{@"state": @(self.followState)}];
    [self updateFollowUI];
}

- (void)updateFollowUI {
    if (!self.followStatusLabel || !self.followDot) return;
    if (self.followState == 1) {
        self.followStatusLabel.text = @"已关注";
        self.followStatusLabel.textColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
        self.followDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    } else {
        self.followStatusLabel.text = @"去关注";
        self.followStatusLabel.textColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
        self.followDot.backgroundColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
    }
}

- (void)showRewardSheet {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
}

- (void)openManualFollowFallback {
    NSString *profileURL = [YZWCServiceCenter officialAccountProfileURL] ?: @"";
    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"公众号：杳知爱吃米饭\n主页：%@", profileURL];
    [YZRuntimeLogger logEvent:@"sheet.follow_tap.copy_fallback" info:@{@"has_url": @(profileURL.length > 0)}];
    [YZWCServiceCenter openBrandProfile:kGHUserName fromViewController:self completion:^(BOOL opened) {
        [YZRuntimeLogger logEvent:@"sheet.follow_tap.result" info:@{
            @"opened": @(opened),
            @"route": [YZWCServiceCenter lastOfficialAccountOpenResult] ?: @"none"
        }];
        if (!opened) {
            [self showToast:@"跳转失败，已复制公众号名称和主页链接"];
        }
    }];
}

- (void)handleFollowTap {
    // 底部胶囊以稳定为先：受限账号和部分微信版本直接调用自动关注私有接口可能闪退。
    // 点击仍要作为公众号主页入口；跳转失败时保留复制公众号名称作为兜底。
    [YZRuntimeLogger logEvent:@"sheet.follow_tap.begin" info:@{@"state": @(self.followState)}];
    [self openManualFollowFallback];
}

- (NSString *)runtimeFeedbackReport {
    NSString *followText = @"无法确认";
    if (self.followState == 1) followText = @"已关注";
    else if (self.followState == 0) followText = @"未关注";

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:@"小杳知运行反馈"];
    [lines addObject:[NSString stringWithFormat:@"插件版本: %@", [YZPluginLifecycle sharedInstance].pluginVersion ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"微信版本: %@", [YZWCServiceCenter getWeChatVersion] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"微信包名: %@", [YZWCServiceCenter getBundleIdentifier] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"系统版本: iOS %@", [YZWCServiceCenter getSystemVersion] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"设备标识: %@", [YZWCServiceCenter getDeviceModel] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"证书类型: %@", [YZWCServiceCenter getCertificateType] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"证书到期: %@", [YZWCServiceCenter getCertificateExpirationDate] ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"公众号状态: %@ (%ld)", followText, (long)self.followState]];
    [lines addObject:[NSString stringWithFormat:@"最近路由: %@", [YZWCServiceCenter lastOfficialAccountOpenResult] ?: @"none"]];
    [lines addObject:@"---- 最近运行日志 ----"];

    NSString *logText = [YZRuntimeLogger recentLogText];
    [lines addObject:logText.length > 0 ? logText : @"暂无运行日志"];
    return [lines componentsJoinedByString:@"\n"];
}

- (void)copyRuntimeFeedback {
    [self refreshFollowStatus];
    UIPasteboard.generalPasteboard.string = [self runtimeFeedbackReport];
    [YZRuntimeLogger logEvent:@"sheet.runtime_feedback.copied"];
    [self showToast:@"运行日志已复制，可直接反馈"];
}

- (void)showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *container = self.view.window ?: self.view;
        if (!container.window) {
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
                break;
            }
            if (keyWindow) container = keyWindow;
        }

        UILabel *toast = [[UILabel alloc] init];
        toast.text = msg;
        toast.font = [UIFont systemFontOfSize:13];
        toast.textColor = UIColor.whiteColor;
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.layer.cornerRadius = 10;
        toast.clipsToBounds = YES;
        toast.alpha = 0;

        CGSize s = [msg boundingRectWithSize:CGSizeMake(260, 60) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:toast.font} context:nil].size;
        CGFloat tw = MIN(ceil(s.width)+36, 280), th = ceil(s.height)+20;
        CGRect bounds = container.bounds;
        CGFloat toastY = bounds.size.height * 0.7;
        if (container == self.view && self.bottomBar) {
            toastY = CGRectGetMinY(self.bottomBar.frame) - th - 12;
        }
        toastY = MAX(96, MIN(toastY, bounds.size.height - th - 36));
        toast.frame = CGRectMake((bounds.size.width-tw)/2.0, toastY, tw, th);
        [container addSubview:toast];

        [UIView animateWithDuration:0.22 animations:^{ toast.alpha = 1; } completion:^(BOOL d){
            [UIView animateWithDuration:0.22 delay:1.8 options:UIViewAnimationOptionCurveEaseIn animations:^{ toast.alpha = 0; } completion:^(BOOL d2){ [toast removeFromSuperview]; }];
        }];
    });
}

#pragma mark - Presentation

- (void)presentInWindow:(UIWindow *)window {
    if (!window) return;

    if (self.view.superview == window && self.isPresented) {
        self.view.frame = window.bounds;
        return;
    }

    BOOL shouldTransition = !self.isPresented;
    if (self.view.superview && self.view.superview != window) {
        [self.view removeFromSuperview];
    }

    self.view.frame = window.bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (shouldTransition) {
        [self beginAppearanceTransition:YES animated:NO];
    }
    [window addSubview:self.view];
    self.isPresented = YES;
    [YZRuntimeLogger logEvent:@"sheet.present_in_window"];
    if (shouldTransition) {
        [self endAppearanceTransition];
    }
}

- (void)presentFromTopViewController {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (!keyWindow) keyWindow = ((UIWindowScene *)scene).windows.firstObject;
            break;
        }
    }
    if (!keyWindow) {
        id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
        if ([delegate respondsToSelector:@selector(window)]) keyWindow = delegate.window;
    }
    [self presentInWindow:keyWindow];
}

- (void)dismissAnimated {
    BOOL shouldTransition = self.isPresented;
    if (shouldTransition) {
        [self beginAppearanceTransition:NO animated:NO];
    }
    self.view.userInteractionEnabled = NO;
    [self.view.layer removeAllAnimations];
    [self.view removeFromSuperview];
    self.isPresented = NO;
    if (shouldTransition) {
        [self endAppearanceTransition];
    }
    [self restoreInteractivePopGesture];
    [YZRuntimeLogger logEvent:@"sheet.dismiss"];
}

- (void)dismissAnimatedWithCompletion:(void(^)(void))completion {
    [self dismissAnimated];
    if (completion) completion();
}

- (void)refreshAvatar {
    UIImage *localAvatar = [YZWCServiceCenter getSelfAvatar] ?: [self avatarFromWeChatNavigationStack];
    if (localAvatar && self.avatarView) {
        self.avatarView.image = localAvatar;
    }
}

- (void)scheduleAvatarRetryIfNeeded {
    if (self.avatarView.image != nil) return;

    NSArray<NSNumber *> *delays = @[@0.5, @1.5, @3.0];
    for (NSNumber *d in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.avatarView.image != nil) return;
            [self refreshAvatar];
        });
    }

    // 后台线程允许网络下载头像
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIImage *avatar = [YZWCServiceCenter getSelfAvatar];
        if (avatar) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.avatarView.image == nil) {
                    self.avatarView.image = avatar;
                }
            });
        }
    });
}

@end
