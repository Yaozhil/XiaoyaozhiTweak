# 问题与风险

## 已知问题

- 用户真机反馈：倒计时结束点击“已知晓”直接闪退，手机系统里找不到 ips；用户提供本地日志后确认崩溃为 `NSInvalidArgumentException`：`-[__NSDictionaryI subscribeBizLive]: unrecognized selector`，触发点在自动关注 `tryAddBrandContact:context:` 附近。根因是把普通 `NSDictionary` 当成微信品牌号关注上下文传入，微信内部期望上下文对象响应 `subscribeBizLive`。当前已热修为只使用真实上下文类且必须响应 `subscribeBizLive`，否则不调用高风险自动关注。
- 用户真机反馈：点击“投喂一下”曾直接黑屏；原因指向菜单入口 present 微信私有扫码控制器后未成功跳转。当前已按用户要求移除所有可见赞赏行为，仅保留震动。
- 用户真机反馈：停在功能列表长时间不动曾导致微信闪退；此前高风险点是菜单页后台线程调用微信私有 `CContactMgr`/头像获取链路，已收回主线程并移除异步头像刷新。
- 用户测试微信账号处于功能受限状态，无法作为公众号自动关注成功与否的最终验证样本。
- 底部关注失败兜底曾只提示“请手动搜索关注”，原因是 `openBrandProfile` 过度依赖 `CContactMgr`/本地联系人对象；后续调用 `weixin://dl/businessWebview` 会因定制包 bundle id 不同而跳到官方微信并弹 `invalid_source`，自建 WKWebView 又会显示“请在微信客户端打开链接”，动态枚举出的微信 Web/WebView/load/jump 分发服务真机仍会黑屏。当前底部入口保留跳转，但只尝试固定白名单里的高层 URL/Link router，命不中时复制公众号名称并提示搜索关注。
- 用户最新真机反馈：点击底部胶囊仍直接黑屏，并显示已复制公众号信息。结合 WCPulse 1.6-2+1/1.6-3 字符串对比，当前风险点不是用户提供的 mp 链接本身，而是插件浮层场景下直接打高层 URL router 可能触发有副作用但未完成的微信页面栈变化；当前已新增 `official_account.open.try/miss/recover` 日志和失败恢复逻辑，下一次反馈需重点看最后一次命中的类/selector 以及是否触发 recover。
- 用户补充：黑屏后只能划掉后台重开微信，导致之前复制的运行反馈只包含重开后的内存日志，看不到黑屏前点击链路。当前已改为重开后合并读取文件日志，并把底部点击和公众号路由关键事件同步落盘；仍需真机验证下一次黑屏后反馈是否包含 `sheet.follow_tap.begin`、`official_account.open.begin`、`official_account.open.skip_void/try`。
- 最新运行反馈证明底部点击没有进入任何 URL router 尝试：`last=none` 且没有 `open.try/skip_void`。因此当前黑屏不是 router selector 副作用，而是插件浮层先被 dismiss，随后无路由可跳导致底层界面暴露为黑屏。当前已在 dismiss 前加 `official_account.open.preflight`，无可用 router 时不再关闭浮层。
- 预检版本已确认“不黑屏但不跳转”，`targets=4/responding=0` 表明当前微信 8.0.74 没有可用高层 URL router。已新增 WCPulse 明确出现的已知 WebView/A8Key 初始化器兜底；该路线曾有历史黑屏风险，当前只在初始化器真实存在时尝试，并保留详细日志以便真机验证。
- WebView/A8Key 兜底真机命中 `MMWebViewController initWithURL:presentModal:extraInfo:` 后仍黑屏，说明该路线不可作为底部入口实现。当前必须撤销 WebView present，只保留无副作用探针，继续寻找 `LinkTextParser/onLinkClicked` 真实点击链路。
- 撤销 WebView 后新增的全运行时 selector 枚举探针导致底部点击后直接闪退，日志停在 `official_account.open.preflight`。当前已删除 `objc_getClassList` 全类枚举，只保留固定类探针，避免探针本身成为崩溃源。
- 黑屏与闪退均已止住后，底部仍不跳转，固定探针显示可用线索集中在 `WebViewA8KeyLogicImpl`。当前已增加固定 A8Key 尝试，但其内部是否需要真实 WebView 上下文仍待真机确认；若只记录 `a8key.failed` 或命中后仍不跳，需要继续寻找 `LinkTextParser/onLinkClicked` 所属上下文。
- A8Key 尝试真机日志显示 `hasUrlPermission=false` 后调用 `goToURL:withCustomerCookies:` 导致点击闪退，当前已撤销 A8Key 实际调用。后续实现跳转必须避开高层 URL router、WebView VC、A8Key 直接调用，转向 `LinkTextParser`/真实点击上下文。
- 微信对话框内点击同一 mp 链接可跳转，说明裸 URL 路线缺少消息上下文。曾尝试 `CMessageMgr/CMessageWrap/AddMsg` 证明消息链路可命中，但这会在文件传输助手产生客户可见消息，用户明确指出像账号异常；当前已撤销该方案，后续不得把可见发消息作为客户版公众号入口。
- 底部胶囊曾只显示“已复制公众号名称，请搜索关注”，新增判断显示原因可能是 `viewController.navigationController` 和微信根导航均未命中，旧代码因此完全跳过资料页创建；当前已增加无 pushNav 时的 present 兜底。
- 17 系列设备曾因 `iPhone18,*` 未映射而只显示 `iPhone`，已补齐映射并优化未知机型回退。

## 风险与待确认

- 新增运行日志只做本地滚动记录与一键复制反馈，不主动上传；后续真机需确认“运行日志”菜单能成功复制报告，且报告里能看到 `official_account.open.*`、`brand_follow_state.*`、`sheet.follow_tap.*` 等关键事件。
- `Core/YZConfigManager.m` 中配置写入 `plugin_config` 字典，但 `valueForKey:` 单项读取先查同 suite 的顶层 key，再回落到启动时合并后的 `sDefaultConfig`；运行中通过 `setValue:forKey:` 改配置后，当前进程内可能读不到最新值，表现为开关或参数需要重启才生效。
- 当前 `Guard/YZCrashGuard.m` 的 signal handler 中会调用 Objective-C、日志格式化和文件写入；这类操作在真实 signal 崩溃上下文中不安全，可能让崩溃记录本身变成额外风险。后续建议改为轻量标记/下次启动汇总。
- 当前隐私声明/报告包含“不发起网络请求”，但 `WeChat/YZWCServiceCenter.m` 的头像兜底逻辑存在 `NSURLSession` 下载头像路径；需要二选一：要么去掉网络下载头像兜底，要么把隐私说明改成“仅在微信沙盒内、为头像兜底读取微信头像 URL”并允许用户关闭。
- `UI/YZGlassSheetController.m` 主菜单“常用功能”仍展示右箭头，但点击只震动并 toast“暂未开放”；作为重度用户体验会误以为入口损坏，建议改成禁用态、移除箭头，或升级为真实诊断入口。
- 公众号自动关注依赖微信私有 `CContactMgr`/品牌号相关 selector；已扩大兼容候选并加入 `CContact/MMContact` 参数兜底，但不同微信版本仍可能变更 selector 或内部校验。
- 新接入的 `BrandDirectlyOperateContactLogic -> tryAddBrandContact:context:` 来自参考插件二进制线索，属于更贴近微信品牌号逻辑的自动关注路径；但上下文字段仍是按可见类名和常见 setter/KVC 保守填充，需要 GitHub Actions 构建和真机验证确认不同微信版本是否命中。
- `followBrand:` 只能可靠判断“关注请求是否已成功发出/selector 是否命中”；当前已恢复首次弹窗调用该方法，但微信服务端是否最终完成关注，需要正常账号真机验证。
- `brandFollowState:` 只信任 subscribe/subscribed 类明确状态；若某微信版本完全不暴露关注状态，会返回无法确认。前台保留状态布局，但只在确认已关注时显示“已关注”，其他情况显示“去关注”。
- 用户自己的已关注账号曾被显示为未关注，说明 subscribe/subscribed 字段并非所有微信版本都会暴露真实状态；当前底部入口不再显示“未关注”字样。
- 参考插件 `com.shtm.xos_1.4.5_iphoneos-arm64e.deb` 为 `data.tar.lzma`，当前 Windows 环境缺少 lzma/xz 工具，暂未能读取内部动态库；`微信助手_3.9-5_无根.deb` 可读取并已提取 selector 线索。
- `itenfay/WeChat_tweak` 的公众号关注代码年代较早且在当前仓库文件中是注释/历史示例，selector 兼容性仍需真机验证；已只提取最小兼容思路，没有引入网页或外部 scheme。
- `ways0210/WechatEnhance` 未包含自动关注公众号实现，但其 `NavigationTitleHooks.xm` 有可用的 `ContactInfoViewController` 跳转模式：关闭弹窗后重新获取顶层控制器再 push/present，当前已采用。
- “小游戏”功能已按用户要求先移除，当前不再作为调试范围。
- 用户反馈未关注/账号受限时插件仍显示“已关注”，已定位为关注判断过于乐观；当前已移除 contact 存在即已关注的兜底，但仍需真机确认不同微信版本的 `CContactMgr` 状态 selector 是否命中。
- 用户提供的调试截图显示微信原生 WebView 能打开 mp 页面，但出现“操作频繁，请稍后再试”；这属于服务端频控/账号状态风险，插件只能兜底打开主页，无法保证自动关注或绕过频控。
- 若从插件弹层直接 push 微信页面，目标页面可能被当前弹层遮住；当前已改为插件弹层触发时先 dismiss 再展示，仍需真机确认动画结束后 push 是否可见。
- 客户测试上一版本出现“能跳公众号主页但无法操作，必须杀后台重开”，高度疑似插件 window overlay 未移除而拦截触摸；当前已改为命中 `dismissAnimatedWithCompletion:` 时先移除 overlay 再跳转，仍需客户复测确认。
- 打开公众号主页/资料页可能让微信本地生成 contact 缓存，导致列表状态字段误报“已关注”；当前关注判断已改为只信任 subscribe/subscribed 类明确字段，且打开主页链路不再主动写入本地 contact。
- 点击底部胶囊时，`1.1.7` 出现黑屏但有返回按钮，判断为品牌/公众号专用资料页控制器存在但不适合当前初始化参数；当前已停用所有私有资料页 VC push，不再伪造 contact。
- 用户反馈后续仍黑屏并且返回后全黑，说明通用/品牌资料页 VC push 路线整体会污染微信导航栈；底部入口已停用私有资料页 VC。
- 用户真机反馈 `6af785b` 点击底部关注后只剩系统状态栏、其余全黑，说明微信 AppDelegate/Universal Link 路由 `profile_ext` 也不适合从插件 overlay 场景触发；当前已移除该路线。
- 用户补充旧方案能进入公众号主页但不能上下滑动，风险点更像插件 view/window 透明遮罩没有移除导致触摸被拦截；当前 `dismissAnimated` 已在移除 view 前禁用 `userInteractionEnabled` 并清理动画。
- 受限账号进入公众号主页只看到“发送消息”、没有关注按钮，可能是微信账号限制或服务端状态导致；插件只能打开正确的微信内部主页，无法绕过微信限制强制关注。
- `WeChat-2026-06-05-004816.ips` 显示底部点击闪退为 `doesNotRecognizeSelector`/`SIGABRT`，触发线程是主线程手势，调用栈经过插件 dylib；高风险点为直接调用微信私有 WebView 构造器、自动关注 selector 或未知 URL/Web 路由服务。当前底部胶囊不直接调用自动关注私有接口，也不再直接构造/push WebView VC 或动态探测微信 URL/Web 路由服务，只走固定高层 URL/Link router 白名单。
- Windows 本机缺少 Theos/make/clang/dpkg-deb，编译级验证依赖 GitHub Actions。

## 失败尝试

- 旧的赞赏扫码直达链路曾多次导致卡死或黑屏，当前已完全退出产品路径。
