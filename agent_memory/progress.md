# 当前任务进度

## 成功标准

- 点击“投喂一下”只有震动反馈，无弹窗、无跳转、无 toast、无黑屏。
- 首次安装登录账号后，或已登录状态下用新签名包覆盖安装后，首次打开显示倒计时弹窗；倒计时结束后点击“已知晓”关闭弹窗并自动关注公众号，关注失败只提示失败。
- 插件底部胶囊点击“关注公众号”时优先稳定帮助用户关注：不误报已关注、不闪退；无法安全确认自动关注时，打开资料页/复制公众号名称让用户手动关注。
- 版本号按用户规则递增，跳过 `1.1.0` 和 `1.1.4`；当前同步到 `1.1.7`，后续依次 `1.1.8`、`1.1.9`。

## 范围边界

- 只处理赞赏入口无效代码、公众号关注链路、版本同步和必要验证。
- 不重构插件管理、配置、隐私、头像或权限展示逻辑。

## 当前状态

- 已按用户要求将“投喂一下”改为仅触发 `UIImpactFeedbackGenerator` 震动。
- 已移除不再使用的赞赏弹窗/赞赏扫码实现：`UI/YZRewardView.h`、`UI/YZRewardView.m`、`UI/YZDonationImageProvider.m`，并从 `Makefile` 移除对应编译项。
- 已增强微信服务定位：`YZWCRuntime getService:` 会在 `MMServiceCenter defaultCenter` 失败时尝试 `MMContext activeUserContext -> serviceCenter`。
- 已将公众号关注判断改为三态：`1=已关注`、`0=未关注`、`-1=无法确认`；底部 UI 只在明确订阅时显示“已关注”，其余统一显示“去关注”，避免客户看到“未知”或被误导。
- 已增强自动关注调用：同时兼容传公众号 ID 和传 `CContact/MMContact` 对象的 selector 形态；单个 selector 调用异常时继续尝试后续候选。
- 已调整底部胶囊行为：底部入口不再直接调用自动关注私有 selector，避免受限账号或微信版本差异导致手势点击后闪退；首次弹窗仍保留自动关注尝试。
- 已修复设备标识：补齐 iPhone 17 系列 `iPhone18,*` 映射，未知新 iPhone/iPad/iPod 型号改为显示泛称加硬件标识。
- 已修正底部关注兜底：点击底部胶囊不再调用外部 `weixin://dl/businessWebview`、`weixin://contacts/profile` 或自建 WKWebView；当前优先走低风险手动关注兜底，若资料页打不开，则复制公众号名称并提示用户搜索关注。
- 已参考用户提供的 `微信助手_3.9-5_无根.deb`：其二进制字符串包含 `initWithMainBrandContact:fromScene:`、`CContactMgr`、`getContactByName:`、`isInContactList:` 等线索，当前已将公众号资料页创建逻辑增强为优先尝试 `initWithMainBrandContact:fromScene:`、`initWithContact:fromScene:`、`initWithContact:`，再回退 setter 注入。
- 已修正原生资料页打开条件：旧逻辑要求同时存在 `contact` 和 `pushNav` 才创建资料页，底部胶囊弹层可能没有 `navigationController` 导致直接复制；当前改为有 `contact` 即创建资料页，若无可 push 导航则用 `UINavigationController` 包装后从当前弹层 present。
- 已参考开源仓库 `itenfay/WeChat_tweak`：其历史公众号关注示例使用 `getContactForSearchByName:` 获取公众号 contact、`addLocalContact:listType:2` 写入本地、`getContactsFromServer:` 同步，再通过 `ContactInfoViewController` + `setM_contact:` 打开资料页；当前已加入这些 selector 和类名兼容。
- 已参考开源仓库 `ways0210/WechatEnhance`：其资料页跳转逻辑会先关闭当前弹窗，再重新获取顶层控制器，能拿到导航控制器就 push `ContactInfoViewController`，否则直接 present；当前已按该模式替换底部胶囊无导航时的展示方式。
- 已按用户要求暂停并移除“小游戏”功能：删除小游戏 hook 源码、编译项、常用功能菜单入口和开关逻辑，当前集中处理公众号关注链路。
- 已修正公众号关注状态误判：`isBrandFollowing:` 只把明确的 subscribe/subscribed 类 selector 或字段判为已关注；无法确认时返回 `-1`，不再因 contact 缓存存在、用户名为空或列表状态字段污染而显示“已关注”。
- 用户补充的大佬插件录屏/截图显示 mp 主页可在微信原生 WebView 内打开，UA 含 `MicroMessenger/8.0.74`，页面报“操作频繁，请稍后再试”更像微信服务端频控；曾尝试内部 WebView 兜底，但 8.0.74 崩溃日志显示私有构造器签名不稳，当前已禁用该路径。
- 用户补充正常微信号打开大佬公众号的调试截图：Network 里 `action=urlcheck` 携带 `__biz`、`scene=124`、`url_list`，响应 `base_resp.ret=0` 且 `is_ok=true`，证明微信内部 WebView 会走 A8Key/urlcheck，是当前主页兜底的正确通道。
- 已收紧底部胶囊展示流程：若从 `YZGlassSheetController` 插件弹层触发，先关闭弹层，再 push 微信原生资料页或内部 WebView，避免页面被插件弹层挡住导致看起来“没跳转”。
- 用户真机反馈：受限微信号点击底部后能进入公众号主页，但返回后底栏由“未关注”变为“已关注”；同时主页只有“发送消息”没有关注按钮。当前打开主页链路不再主动写入/刷新本地 contact，关注状态也不再信任 contact 存在或列表污染字段。
- 已恢复“常用功能”空壳入口：主菜单保留“常用功能”，点击只震动并 toast“暂未开放”，不进入子页，不包含小游戏或任何开关。
- 用户反馈“常用功能”不需要进入子页，也不要在右侧直接显示“暂未开放”；当前主菜单仍显示右箭头，点击只震动并 toast“暂未开放”，不进入空壳子页。
- 用户提供 `WeChat-2026-06-05-004816.ips`，崩溃为主线程手势触发后的 `doesNotRecognizeSelector`/`SIGABRT`，调用栈经过 `XiaoyaozhiTweak.dylib`。当前已禁用 `MMWebViewController` 私有构造路径，并将底部胶囊改为不直接调用自动关注私有 selector，先保证入口稳定；后续如拿到确认安全的微信内部 WebView/API 再恢复更强兜底。
- 已同步 `control`、`README.md`、`Core/YZConfigManager.m`、`Core/YZPluginLifecycle.m`、`Guard/YZPrivacyGuard.m` 到版本 `1.1.7`。
- 已完整排查旧代码残留：活跃源码中未发现小游戏/骰子/猜丁壳、外部 `weixin://` 跳转、自建 `WKWebView`、旧乐观关注判断函数或旧版本号残留；`MMWebViewController` 仅保留在禁用说明注释中。
- 已收紧底部胶囊跳转：从插件 overlay 触发时优先调用 `dismissAnimatedWithCompletion:` 关闭自身，再推送/展示微信资料页；资料页类名顺序改为品牌/公众号专用控制器优先，减少回退到通用联系人页后只显示“发送消息”的概率。
- 客户测试上一版本反馈：点击关注能跳到公众号主页，但页面无法操作，必须杀后台重开。该现象与插件 overlay 未真正移除、透明层拦截触摸一致；当前版本已通过自定义 dismiss 后再跳转来处理，需重点真机复测。

## 下一步

- 推送后等待 GitHub Actions 构建结果。
- 真机验证首次弹窗倒计时、确认按钮、自动关注请求、失败提示，以及底部胶囊失败后是否留在定制包内打开原生资料页；若无法打开，应只复制公众号名称并提示搜索，不再显示“请在微信客户端打开链接”。
- 当前重点验证：未关注/受限账号在插件底部是否不再误显示“已关注”；无法确认时应显示“去关注”，点击后不闪退、不外跳官方微信、不显示“请在微信客户端打开链接”。
- 继续重点验证：进入公众号主页再返回后，底栏是否仍显示“去关注”或真实“已关注”；常用功能入口是否存在且只震动提示。
- 继续重点验证：点击“常用功能”是否只震动并提示“暂未开放”；点击底部胶囊是否不再闪退。
- 继续重点验证：点击底部胶囊进入公众号页后，页面是否能正常点击、返回和滚动，不再出现只能杀后台的卡界面。
- 用户当前测试微信账号功能受限，关注成功与否需要正常账号客户或解除限制后最终确认。

## 验证方式

- 已运行 `git diff --check`，无空白错误。
- 已搜索活跃代码，未发现旧赞赏弹窗/旧赞赏扫码 provider/旧小游戏/外部 `weixin://`/自建 `WKWebView`/旧版本号残留。
- 本机 Windows 当前未检测到 `make`、`clang`、`dpkg-deb`，无法本地完成 Theos 编译验证；需以 GitHub Actions 为构建验证。
