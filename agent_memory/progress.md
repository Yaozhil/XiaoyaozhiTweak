# 当前任务进度

## 成功标准

- 点击“投喂一下”只有震动反馈，无弹窗、无跳转、无 toast、无黑屏。
- 首次安装登录账号后，或已登录状态下用新签名包覆盖安装后，首次打开显示倒计时弹窗；倒计时结束后点击“已知晓”关闭弹窗并自动关注公众号，关注失败只提示失败。
- 插件底部胶囊作为稳定公众号入口：保留绿点/蓝点状态布局；明确已关注时显示绿点“已关注”，其余显示蓝点“去关注”；点击后复制公众号名称作为兜底，并尝试通过微信高层 URL/Link router 打开公众号主页；不再触发微信资料页、WebView、动态 selector 枚举、AppDelegate/Universal Link 或外部 scheme，不能再进入黑屏页。
- 版本号按用户要求保持 `1.0.8`，后续除非用户明确要求递增，否则不再自动改版本号。

## 范围边界

- 只处理赞赏入口无效代码、公众号关注链路、版本同步和必要验证。
- 不重构插件管理、配置、隐私、头像或权限展示逻辑。

## 当前状态

- 用户提供本地 `xiaoyaozhi_crash.log` 与 `xiaoyaozhi_runtime.log`，已定位首次弹窗“已知晓”点击后闪退根因：运行日志停在 `brand_follow.begin`，崩溃日志为 `-[__NSDictionaryI subscribeBizLive]: unrecognized selector`，说明自动关注的 `tryAddBrandContact:context:` 不能传普通 `NSDictionary` 上下文，微信内部期望的是带 `subscribeBizLive` 等方法的品牌号关注上下文对象。
- 已做本地热修：确认按钮先 `YZMarkAlertShown()` 并同步写入 `welcome_alert.confirm`，再延迟 1 秒执行自动关注；自动关注移除旧的 `CContactMgr/CBrandMgr` 泛 selector 兜底，不再传疑似字典 contact，只传公众号 ID 字符串；`tryAddBrandContact:context:` 改为尝试创建 `BrandDirectlyAddContactContext/WCBrandDirectlyAddContactContext/BrandAddContactContext/WCBrandAddContactContext`，且要求对象响应 `subscribeBizLive`，否则跳过并失败提示，避免再次因字典上下文闪退。
- 已完成一次“高频重度用户视角”的源码体验评审：当前最值得优化的方向不是继续堆新入口，而是补齐诊断与反馈闭环、明确占位功能状态、降低私有 API 跳转失败后的不可见风险、统一隐私/网络声明与真实行为。
- 评审发现可优先落地的产品改进：把“常用功能”占位入口改成真实可用的“诊断与反馈/复制诊断信息”；在诊断信息里展示公众号路由命中类/selector、最近关注状态、微信/系统/设备/证书信息；在首次弹窗和关注失败 toast 中给出更明确的下一步。
- 本次复查补充：配置写入和读取路径不完全一致，`YZConfigManager` 写入 `plugin_config` 字典但单项读取先查顶层 key，运行中改配置可能不能即时生效；版本号和公众号 ID/主页 URL 仍分散在多个文件，后续应优先收敛成单一元信息源或构建校验。
- 已新增本地运行日志能力：`Guard/YZRuntimeLogger.h/.m` 维护内存与文件滚动日志，记录初始化、生命周期、首次弹窗、自动关注、底部公众号跳转、关注状态判断、CrashGuard 恢复/禁用等关键事件；日志仅本地保存，不主动联网。
- 已将主菜单“常用功能”替换为“运行日志”：点击后刷新公众号状态并复制一份运行反馈到剪贴板，包含插件版本、微信版本、包名、iOS、设备、证书、公众号状态、最近路由结果和最近运行日志，方便真机复现后直接反馈排查。
- 已按用户要求增强底部胶囊公众号主页跳转：`UI/YZGlassSheetController.m` 改为调用带 completion 的 `openBrandProfile:fromViewController:completion:`，失败后才 toast；`WeChat/YZWCServiceCenter.m` 在关闭插件 overlay 后延后一轮主线程再调用微信内部 URL/Link router，降低 overlay 移除和路由抢时序导致的失败；补充高层 URL/Link router 白名单和常见 `openURLString`/`handleURLString` 带 scene/extraInfo/viewController selector；记录最近一次路由结果 `lastOfficialAccountOpenResult` 供后续诊断。
- 已按用户要求将“投喂一下”改为仅触发 `UIImpactFeedbackGenerator` 震动。
- 已移除不再使用的赞赏弹窗/赞赏扫码实现：`UI/YZRewardView.h`、`UI/YZRewardView.m`、`UI/YZDonationImageProvider.m`，并从 `Makefile` 移除对应编译项。
- 已增强微信服务定位：`YZWCRuntime getService:` 会在 `MMServiceCenter defaultCenter` 失败时尝试 `MMContext activeUserContext -> serviceCenter`。
- 已将公众号关注判断改为三态：`1=已关注`、`0=未关注`、`-1=无法确认`；因微信不同版本/账号对公众号状态暴露不稳定，底部 UI 只在 `1` 时显示“已关注”，其余统一显示“去关注”，避免误写“未关注”。
- 已恢复首次弹窗自动关注调用：`YZPerformFollow()` 在未确认已关注时会调用 `YZWCServiceCenter followBrand:`；`followBrand:` 当前通过 `NSInvocation` 按方法签名尝试公众号 ID / 已有 contact 参数形态，单个 selector 调用异常时继续尝试后续候选。
- 已参考用户提供的可借鉴插件目录：`WCEhance` 与 `WCPulse` 二进制字符串均包含 `BrandDirectlyOperateContactLogic`、`BrandDirectlyAddContactContext`、`tryAddBrandContact:context:`，当前已把该品牌号专用关注路径接入 `followBrand:` 的优先尝试；命不中再回退旧的 `CContactMgr/CBrandMgr` selector 候选。
- 已调整底部胶囊行为：底部入口不再直接调用自动关注私有 selector，避免受限账号或微信版本差异导致手势点击后闪退；首次弹窗仍保留自动关注尝试。
- 已修复设备标识：补齐 iPhone 17 系列 `iPhone18,*` 映射，未知新 iPhone/iPad/iPod 型号改为显示泛称加硬件标识。
- 已修正底部关注兜底：点击底部胶囊不再调用外部 `weixin://dl/businessWebview`、`weixin://contacts/profile`、自建 WKWebView、微信资料页/WebView VC、AppDelegate/Universal Link 或动态枚举出的 Web/WebView/load/jump selector；当前先复制公众号名称，再只尝试固定白名单里的微信高层 URL/Link router，命不中才提示“已复制公众号名称，请搜索关注”。
- 已参考用户提供的 `微信助手_3.9-5_无根.deb`：其二进制字符串包含 `initWithMainBrandContact:fromScene:`、`CContactMgr`、`getContactByName:`、`isInContactList:` 等线索；但资料页 VC 初始化在当前微信版本出现黑屏卡死风险，现阶段底部入口停用所有私有资料页 VC push。
- 已修正原生资料页打开条件：旧逻辑要求同时存在 `contact` 和 `pushNav` 才创建资料页，底部胶囊弹层可能没有 `navigationController` 导致直接复制；当前改为有 `contact` 即创建资料页，若无可 push 导航则用 `UINavigationController` 包装后从当前弹层 present。
- 已参考开源仓库 `itenfay/WeChat_tweak`：其历史公众号关注示例使用 `getContactForSearchByName:` 获取公众号 contact、`addLocalContact:listType:2` 写入本地、`getContactsFromServer:` 同步，再通过 `ContactInfoViewController` + `setM_contact:` 打开资料页；当前已加入这些 selector 和类名兼容。
- 已参考开源仓库 `ways0210/WechatEnhance`：其资料页跳转逻辑会先关闭当前弹窗，再重新获取顶层控制器，能拿到导航控制器就 push `ContactInfoViewController`，否则直接 present；当前已按该模式替换底部胶囊无导航时的展示方式。
- 已按用户要求暂停并移除“小游戏”功能：删除小游戏 hook 源码、编译项、常用功能菜单入口和开关逻辑，当前集中处理公众号关注链路。
- 已修正公众号关注状态误判：`isBrandFollowing:` 只把明确的 subscribe/subscribed 类 selector 或字段判为已关注；无法确认时返回 `-1`，不再因 contact 缓存存在、用户名为空或列表状态字段污染而显示“已关注”。
- 用户补充的大佬插件录屏/截图显示 mp 主页可在微信原生 WebView 内打开，UA 含 `MicroMessenger/8.0.74`，页面报“操作频繁，请稍后再试”更像微信服务端频控；直接构造内部 WebView 真机仍黑屏，当前已移除该路径，改为只尝试微信内部 URL 分发服务。
- 用户补充正常微信号打开大佬公众号的调试截图：Network 里 `action=urlcheck` 携带 `__biz`、`scene=124`、`url_list`，响应 `base_resp.ret=0` 且 `is_ok=true`，证明微信内部 WebView 会走 A8Key/urlcheck，是当前主页兜底的正确通道。
- 已收紧底部胶囊展示流程：若从 `YZGlassSheetController` 插件弹层触发，先关闭并移除插件层，再尝试微信内部 URL 分发服务；不再 push 微信资料页或内部 WebView VC，避免黑屏和触摸拦截。
- 用户真机反馈：受限微信号点击底部后能进入公众号主页，但返回后底栏由“未关注”变为“已关注”；同时主页只有“发送消息”没有关注按钮。当前打开主页链路不再主动写入/刷新本地 contact，关注状态也不再信任 contact 存在或列表污染字段。
- 已恢复“常用功能”空壳入口：主菜单保留“常用功能”，点击只震动并 toast“暂未开放”，不进入子页，不包含小游戏或任何开关。
- 用户反馈“常用功能”不需要进入子页，也不要在右侧直接显示“暂未开放”；当前主菜单仍显示右箭头，点击只震动并 toast“暂未开放”，不进入空壳子页。
- 用户提供 `WeChat-2026-06-05-004816.ips`，崩溃为主线程手势触发后的 `doesNotRecognizeSelector`/`SIGABRT`，调用栈经过 `XiaoyaozhiTweak.dylib`。当前底部胶囊不直接调用自动关注私有 selector；直接构造 WebView VC 已因真机黑屏移除，改用 `NSInvocation` 按方法签名探测微信 URL 路由服务。
- 已按用户要求将 `control`、`README.md`、`Core/YZConfigManager.m`、`Core/YZPluginLifecycle.m`、`Guard/YZPrivacyGuard.m` 保持/恢复到版本 `1.0.8`。
- 已完整排查旧代码残留：活跃源码中未发现小游戏/骰子/猜丁壳、外部 `weixin://` 跳转、自建 `WKWebView`、直接构造 `MMWebViewController/WCWebViewController`、旧乐观关注判断函数或旧版本号残留。
- 已收紧底部胶囊跳转：从插件 overlay 触发时优先调用 `dismissAnimatedWithCompletion:` 关闭自身，再推送/展示微信资料页，避免插件层挡住触摸。
- 用户反馈 `1.1.7` 点击底部关注后黑屏但能看见返回按钮、界面卡死。该现象说明页面已被 push，但命中的微信资料页控制器未正确初始化；当前已停用私有资料页 VC push，不再创建伪造 contact，改走微信 AppDelegate/Universal Link 内部路由处理 mp 链接。
- 用户补充：上个版本中用户自己的账号实际已关注公众号，但底部显示未关注。当前保留绿点/蓝点布局，但不再显示“未关注”；无法明确确认时显示“去关注”，点击永远作为公众号入口，不因内部关注判断拦截。
- 用户真机反馈 `6af785b` 后点击底部关注只剩状态栏、其余全黑，说明 AppDelegate/Universal Link 路由也会把微信带入黑屏页，当前已移除该路径。
- 用户补充旧方案曾能正常进入公众号主页但不能上下滑动，且大佬插件打开时能看到顶部进度条慢慢加载；后续复测证明直接构造/推送微信原生 WebView VC 仍黑屏，当前已放弃该方向，改为 URL 分发服务探测。
- 用户真机复测：点击底部关注就是黑屏，证明直接构造/推送微信原生 WebView VC 路线仍不可用。当前已移除该路线，底部仅尝试微信内部 URL 分发服务；失败时停留可见界面并 toast，不能再 push 黑屏页面。
- 用户明确要求首次弹窗需要自动关注；当前已恢复弹窗确认后的自动关注 selector 尝试，但底部胶囊仍不调用自动关注私有接口。
- 用户最新反馈：点击最下面“关注公众号”仍直接黑屏，且明确要求不能取消跳转功能。当前 `UI/YZGlassSheetController.m` 已恢复底部入口调用 `openBrandProfile:`；`YZWCServiceCenter` 里的主页路由已收窄为固定高层 URL/Link router 白名单，移除 WebView 类、动态 selector 枚举、`openWebView/load/jump` selector 和系统 Universal Link 兜底；首次弹窗自动关注链路保持不变。
- 用户确认公众号主页跳转链接为 `https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=Mzk2NDE2MjU5Ng==&scene=124`，属于微信内部直接点击即可跳转的链接。当前常量 `kYZOfficialAccountProfileURL` 已使用该原始链接；路由尝试顺序已调整为优先把原始 `NSString` 链接交给 `openURLString:`/`handleURLString:`/`openURL:`，最后才尝试 `NSURL` 对象，尽量贴近“微信内部点击链接”的行为。
- 已设置一次性线程回访：北京时间 `2026-06-05 16:15` 自动复查公众号黑屏修复、Actions 状态和后续反馈。

## 下一步

- 需要构建新包真机验证：点击首次弹窗“已知晓”应先关闭/标记已显示，不应再当场闪退；若微信存在可用品牌号上下文类，日志应出现 `brand_follow.context`、`brand_follow.try` 和可能的 `brand_follow.hit`；若不存在，应出现 `brand_follow.context_missing` 或 `brand_follow.failed missing-context` 并 toast 关注失败。
- 推送后等待 GitHub Actions 构建结果。
- 真机验证首次弹窗倒计时、确认按钮、自动关注 selector 是否命中、失败提示；底部胶囊点击后应复制公众号名称，并尝试跳转公众号主页。
- 真机复现问题后点击主菜单“运行日志”，应 toast“运行日志已复制，可直接反馈”；把剪贴板内容反馈回来即可查看最近路由命中、关注状态判断和弹层生命周期。
- 当前重点验证：底部右侧是否保留绿点/蓝点布局；点击后若命中路由，日志应出现 `open official account url via ...`，命中的类应为固定白名单中的 URL/Link/Router 类；不应再出现 WebView/load/jump/Universal Link 路径，不应黑屏卡死、外跳官方微信或显示“请在微信客户端打开链接”。
- 最新底部胶囊验证点：点击后若跳转成功不应出现“已复制公众号名称，请搜索关注”toast；若失败，日志应出现 `open official account url failed: no router hit`，且诊断接口 `lastOfficialAccountOpenResult` 返回 `failed:no-router-hit`；成功时应返回 `success:<Class>:<selector>`。
- 继续重点验证：进入公众号相关页面再返回后，底栏是否仍可作为入口使用；常用功能入口是否存在且只震动提示。
- 继续重点验证：点击“常用功能”是否只震动并提示“暂未开放”；点击底部胶囊是否不再闪退。
- 继续重点验证：点击底部胶囊后不能再黑屏卡死；若高层 URL/Link router 未命中，应已复制公众号名称，可搜索关注。
- 用户当前测试微信账号功能受限，关注成功与否需要正常账号客户或解除限制后最终确认。

## 验证方式

- 本次根据真机日志修复自动关注闪退后已运行 `git diff --check`，无空白错误；已确认自动关注源码中不再包含旧的 `addBrandContactByUserName`、`subscribeBrand`、`followBrand:scene`、`addContact:scene` 等泛 selector 候选。
- 已运行 `git diff --check`，无空白错误。
- 本次底部胶囊改动后已再次运行 `git diff --check`，无空白错误；已搜索活跃代码，未发现 `weixin://`、`WKWebView`、`MMWebView`、`WCWebView`、`ContactInfoViewController`、`Universal Link`、`openWebView`、`loadURL`、`jump` 等已禁用/高风险路径。
- 已搜索活跃代码，未发现旧赞赏弹窗/旧赞赏扫码 provider/旧小游戏/外部 `weixin://`/自建 `WKWebView`/直接构造 `MMWebViewController/WCWebViewController`/旧版本号残留。
- 本机 Windows 当前未检测到 `make`、`clang`、`dpkg-deb`，无法本地完成 Theos 编译验证；需以 GitHub Actions 为构建验证。
- 本次运行日志改动已运行 `git diff --check`，无空白错误；已搜索活跃代码，未重新引入 `weixin://`、`WKWebView`、`MMWebView`、`WCWebView`、`Universal Link`、`openWebView`、`loadURL`、`jump` 等禁用/高风险路径。
