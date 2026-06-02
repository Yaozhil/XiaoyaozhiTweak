#import "YZGlassSheetController.h"
#import "YZGlassOverlayView.h"
#import "YZAnimator.h"
#import "YZEnvironmentDetector.h"
#import "YZWCServiceCenter.h"
#import "YZConfigManager.h"
#import "YZPluginLifecycle.h"
#import "YZCrashGuard.h"
#import "YZRewardView.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

extern UIImage *YZEmbeddedDonationImage(void);
extern UIImage *YZEmbeddedFollowIconImage(void);

static NSString *const kGHUserName = @"gh_5a0621af5c7d";
static NSInteger const kYZDonationOverlayTag = 95101;
static NSInteger const kYZDonationCardTag = 95102;
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
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:1.0]; // #F2F2F7
    [self buildMainUI];
    [self refreshAvatar];
    [self refreshFollowStatus];
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
    self.followIconView = [self followIconViewWithFrame:CGRectMake(20, 10, 28, 28)];
    [self.followCard addSubview:self.followIconView];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(58, 14, cardW - 172, 20)];
    label.text = @"关注杳知公众号";
    label.font = [UIFont systemFontOfSize:17];
    label.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    [self.followCard addSubview:label];

    self.followDot = [[UIView alloc] initWithFrame:CGRectMake(cardW - 88, 20, 8, 8)];
    self.followDot.layer.cornerRadius = 4;
    [self.followCard addSubview:self.followDot];

    self.followStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(cardW - 74, 14, 60, 20)];
    self.followStatusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.followStatusLabel.textAlignment = NSTextAlignmentLeft;
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
        imageView.contentMode = UIViewContentModeScaleAspectFill;
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
        imageView.contentMode = UIViewContentModeScaleAspectFill;
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
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, shellY + shellSize + 17, w, 34)];
    self.nameLabel.text = @"小杳知";
    self.nameLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    [self.headerView addSubview:self.nameLabel];

    // 版本
    self.versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, shellY + shellSize + 54, w, 22)];
    self.versionLabel.text = [NSString stringWithFormat:@"Version: %@", [YZPluginLifecycle sharedInstance].pluginVersion];
    self.versionLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    self.versionLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
    [self.headerView addSubview:self.versionLabel];
}

#pragma mark - TableView

static NSDictionary *sEntitlementsCache = nil;

- (UIColor *)tableCardColor {
    return [UIColor colorWithRed:0.988 green:0.990 blue:1.0 alpha:1.0];
}

- (UIColor *)certificateBadgeColorForRemainingDays:(NSInteger)days {
    if (days == NSIntegerMin) return [UIColor colorWithWhite:0.56 alpha:1.0];
    if (days < 0) return [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    if (days <= 7) return [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    if (days <= 30) return [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0];
    return [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
}

- (NSArray<NSString *> *)orderedEntitlementNames {
    if (!sEntitlementsCache) sEntitlementsCache = [YZWCServiceCenter getAllEntitlements];

    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSString *name in YZPriorityEntitlementNames()) {
        if (sEntitlementsCache[name]) {
            [ordered addObject:name];
            [seen addObject:name];
        }
    }

    NSArray<NSString *> *remaining = [sEntitlementsCache.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *name in remaining) {
        if (![seen containsObject:name]) [ordered addObject:name];
    }

    return ordered;
}

- (UIView *)statusDotViewWithEnabled:(BOOL)enabled {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 48)];
    container.backgroundColor = UIColor.clearColor;
    UIColor *green = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];

    if (enabled) {
        UIView *halo = [[UIView alloc] initWithFrame:CGRectMake(1, 14, 20, 20)];
        halo.layer.cornerRadius = 10;
        halo.backgroundColor = [green colorWithAlphaComponent:0.18];
        [container addSubview:halo];

        CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        scale.values = @[@0.72, @1.28, @0.72];
        scale.keyTimes = @[@0, @0.56, @1];

        CAKeyframeAnimation *opacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        opacity.values = @[@0.05, @0.34, @0.05];
        opacity.keyTimes = scale.keyTimes;

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[scale, opacity];
        group.duration = 1.45;
        group.repeatCount = HUGE_VALF;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [halo.layer addAnimation:group forKey:@"yz.pulse"];
    }

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(6, 19, 10, 10)];
    dot.layer.cornerRadius = 5;
    dot.backgroundColor = enabled ? green : [UIColor colorWithWhite:0.82 alpha:1.0];
    [container addSubview:dot];
    return container;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    if (self.currentPage == 0) return 1;
    if (self.currentPage == 2) return 1; // 全部权限单分组
    return 5; // 用户信息 应用信息 证书信息 权限信息 查看全部
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    if (self.currentPage == 0) return 3;
    if (self.currentPage == 2) return [self orderedEntitlementNames].count; // 全部权限
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
    cell.indentationLevel = 0;
    cell.indentationWidth = 0;
    cell.textLabel.attributedText = nil;
    cell.detailTextLabel.attributedText = nil;
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];

    // ====== 主菜单 ======
    if (self.currentPage == 0) {
        cell.textLabel.text = @[@"账户信息", @"常用功能", @"投喂一下"][ip.row];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        cell.detailTextLabel.text = @"";
        cell.accessoryView = [self arrowView];
        return cell;
    }

    // ====== 全部权限子页 ======
    if (self.currentPage == 2) {
        return [self entitlementCell:cell atRow:ip.row];
    }

    // ====== 账户信息页 ======
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

    // 日期 + 天数徽章
    NSString *badge;
    if (days == NSIntegerMin) {
        cell.detailTextLabel.text = expDate;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.56 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        return cell;
    } else if (days < 0) {
        badge = @"已过期";
    } else {
        badge = [NSString stringWithFormat:@"剩余 %ld天", (long)days];
    }

    NSString *detail = [NSString stringWithFormat:@"%@  ·  %@", expDate, badge];
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:detail attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightRegular],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.56 alpha:1.0]
    }];
    NSRange badgeRange = [detail rangeOfString:badge];
    if (badgeRange.location != NSNotFound) {
        [attributed addAttributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: [self certificateBadgeColorForRemainingDays:days]
        } range:badgeRange];
    }
    cell.detailTextLabel.attributedText = attributed;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];

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
- (UITableViewCell *)entitlementCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    NSArray *all = [self orderedEntitlementNames];
    if (row >= all.count) {
        cell.textLabel.text = @"";
        return cell;
    }
    NSString *name = all[row];
    BOOL on = [sEntitlementsCache[name] boolValue];

    cell.textLabel.text = name;
    cell.detailTextLabel.text = @"";
    cell.accessoryView = [self statusDotViewWithEnabled:on];
    return cell;
}

#pragma mark - Arrow / Selection

- (UIView *)arrowView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 48)];
    container.backgroundColor = UIColor.clearColor;
    container.userInteractionEnabled = NO;

    UIColor *muted = [UIColor colorWithWhite:0.72 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 14, 12, 20)];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.tintColor = muted;
        imageView.image = [UIImage systemImageNamed:@"chevron.right" withConfiguration:config];
        [container addSubview:imageView];
        return container;
    }

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 10, 16, 28)];
    label.text = @"›";
    label.font = [UIFont systemFontOfSize:22 weight:UIFontWeightRegular];
    label.textColor = muted;
    label.textAlignment = NSTextAlignmentCenter;
    [container addSubview:label];
    return container;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (self.currentPage == 0) {
        if (ip.row == 0) [self goToAccountInfo];
        else if (ip.row == 2) [self showRewardSheet];
        else [self showToast:@"暂未开放"];
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
        [self.tableView layoutIfNeeded];
        [self.tableView setContentOffset:topOffset animated:NO];
    }];
}

- (void)goToAccountInfo {
    self.currentPage = 1;
    sEntitlementsCache = nil; // 刷新缓存
    [self updateBackButtonVisibility];
    [self updateInteractivePopGesture];
    self.navTitle.hidden = NO;
    self.navTitle.text = @"账户信息";
    self.infoButton.hidden = YES;
    [self reloadTableAtTop];
}

- (void)goToAllPermissions {
    self.currentPage = 2;
    [self updateInteractivePopGesture];
    self.navTitle.text = @"全部权限";
    [self reloadTableAtTop];
}

- (void)didTapBack {
    if (self.currentPage == 2) {
        self.currentPage = 1;
        [self updateInteractivePopGesture];
        self.navTitle.text = @"账户信息";
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

#pragma mark - Donation

- (UIImage *)donationImage {
    UIImage *embedded = YZEmbeddedDonationImage();
    if (embedded) return embedded;

    NSArray<NSString *> *paths = @[
        @"/var/jb/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/Library/Application Support/XiaoyaozhiTweak/donation.png",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png",
        @"/Library/MobileSubstrate/DynamicLibraries/XiaoyaozhiDonation.png"
    ];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *path in paths) {
        if ([fileManager fileExistsAtPath:path]) {
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if (image) return image;
        }
    }

    return nil;
}

- (void)dismissDonationSheet {
    UIView *overlay = [self.view viewWithTag:kYZDonationOverlayTag];
    [UIView animateWithDuration:0.20 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (void)handleDonationOverlayTap:(UITapGestureRecognizer *)gesture {
    UIView *overlay = gesture.view;
    UIView *card = [overlay viewWithTag:kYZDonationCardTag];
    CGPoint location = [gesture locationInView:overlay];
    if (card && CGRectContainsPoint(card.frame, location)) return;
    [self dismissDonationSheet];
}

- (void)showDonationSheet {
    if ([self.view viewWithTag:kYZDonationOverlayTag]) return;

    UIImage *donationImage = [self donationImage];
    if (!donationImage) {
        [self showToast:@"未找到赞赏码资源"];
        return;
    }

    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.tag = kYZDonationOverlayTag;
    overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.22];
    overlay.alpha = 0;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:overlay];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDonationOverlayTap:)];
    [overlay addGestureRecognizer:tap];

    CGFloat width = MIN(self.view.bounds.size.width - 48, 330);
    CGFloat imageSize = MIN(width - 56, 252);
    CGFloat cardHeight = imageSize + 164;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - width) / 2.0,
                                                            (self.view.bounds.size.height - cardHeight) / 2.0,
                                                            width,
                                                            cardHeight)];
    card.tag = kYZDonationCardTag;
    card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    card.layer.cornerRadius = 26;
    card.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;
    card.layer.shadowOpacity = 1;
    card.layer.shadowRadius = 28;
    card.layer.shadowOffset = CGSizeMake(0, 12);
    card.clipsToBounds = NO;
    [overlay addSubview:card];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, width, 24)];
    title.text = @"投喂一下";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
    [card addSubview:title];

    UILabel *recipient = [[UILabel alloc] initWithFrame:CGRectMake(24, 52, width - 48, 22)];
    recipient.text = @"赞赏对象：杳杳";
    recipient.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    recipient.textAlignment = NSTextAlignmentCenter;
    recipient.textColor = [UIColor colorWithRed:0.78 green:0.56 blue:0.12 alpha:1.0];
    [card addSubview:recipient];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake((width - imageSize) / 2.0, 84, imageSize, imageSize)];
    imageView.image = donationImage;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.backgroundColor = UIColor.whiteColor;
    imageView.layer.cornerRadius = 18;
    imageView.clipsToBounds = YES;
    [card addSubview:imageView];

    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(20, cardHeight - 50, width - 40, 20)];
    subtitle.text = @"感谢支持小杳知～";
    subtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.textColor = [UIColor colorWithWhite:0.48 alpha:1.0];
    [card addSubview:subtitle];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 44, 10, 34, 34);
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightRegular];
    close.tintColor = [UIColor colorWithWhite:0.60 alpha:1.0];
    [close addTarget:self action:@selector(dismissDonationSheet) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];

    card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL followed = [YZWCServiceCenter isBrandFollowing:kGHUserName];
        self.isFollowed = followed;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateFollowUI];
        });
    });
}

- (void)updateFollowUI {
    if (self.isFollowed) {
        self.followStatusLabel.text = @"已关注";
        self.followStatusLabel.textColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
        self.followDot.backgroundColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    } else {
        self.followStatusLabel.text = @"未关注";
        self.followStatusLabel.textColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
        self.followDot.backgroundColor = [UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1.0];
    }
}

- (void)showRewardSheet {
    [self showToast:@"正在打开赞赏页..."];
    __weak typeof(self) weakSelf = self;
    [YZRewardView openRewardPageWithFallback:^{
        [weakSelf showDonationSheet];
    }];
}

- (void)handleFollowTap {
    if (self.isFollowed) {
        [self showToast:@"已关注 杳知爱吃米饭"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"关注公众号"
                                                                   message:@"\n杳知爱吃米饭\n\n点击关注即可收到最新推送"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关注" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if ([YZWCServiceCenter followBrand:kGHUserName]) {
            self.isFollowed = YES;
            [self updateFollowUI];
            [self showToast:@"已关注 杳知爱吃米饭"];
        } else {
            UIPasteboard.generalPasteboard.string = kGHUserName;
            [self showToast:@"请手动搜索关注 gh_5a0621af5c7d"];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
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
        toast.frame = CGRectMake((self.view.bounds.size.width-tw)/2.0, self.view.bounds.size.height*0.7, tw, th);
        [self.view addSubview:toast];

        [UIView animateWithDuration:0.22 animations:^{ toast.alpha = 1; } completion:^(BOOL d){
            [UIView animateWithDuration:0.22 delay:1.8 options:UIViewAnimationOptionCurveEaseIn animations:^{ toast.alpha = 0; } completion:^(BOOL d2){ [toast removeFromSuperview]; }];
        }];
    });
}

#pragma mark - Presentation

- (void)presentInWindow:(UIWindow *)window {
    if (!window) return;
    self.view.frame = window.bounds;
    [window addSubview:self.view];
}

- (void)presentFromTopViewController {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
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
    } else {
        id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
        if ([delegate respondsToSelector:@selector(window)]) {
            keyWindow = delegate.window;
        }
    }
    [self presentInWindow:keyWindow];
}

- (void)dismissAnimated {
    [self.view removeFromSuperview];
}

- (void)dismissAnimatedWithCompletion:(void(^)(void))completion {
    [self.view removeFromSuperview];
    if (completion) completion();
}

- (void)refreshAvatar {
    UIImage *localAvatar = [YZWCServiceCenter getSelfAvatar] ?: [self avatarFromWeChatNavigationStack];
    if (localAvatar && self.avatarView) {
        self.avatarView.image = localAvatar;
    }

    __weak typeof(self) weakSelf = self;
    [YZWCServiceCenter fetchSelfAvatarWithCompletion:^(UIImage *avatar) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        UIImage *resolved = avatar ?: [strongSelf avatarFromWeChatNavigationStack];
        if (resolved) strongSelf.avatarView.image = resolved;
    }];
}

@end
