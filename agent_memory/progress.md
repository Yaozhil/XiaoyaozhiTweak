# 当前任务进度

## 成功标准

- 点击“投喂一下”只有震动反馈，无弹窗、无跳转、无 toast、无黑屏。
- 首次安装登录账号后，或已登录状态下用新签名包覆盖安装后，首次打开显示倒计时弹窗；倒计时结束后点击“已知晓”关闭弹窗并自动关注公众号，关注失败只提示失败。
- 插件底部胶囊点击“关注公众号”时直接自动关注；如无法确认关注成功，再跳转公众号资料页让用户手动关注，兜底失败则复制公众号 ID 并提示搜索。
- 版本号按用户规则递增，跳过 `1.1.0` 和 `1.1.4`；当前同步到 `1.1.6`，后续依次 `1.1.7`、`1.1.8`。

## 范围边界

- 只处理赞赏入口无效代码、公众号关注链路、版本同步和必要验证。
- 不重构插件管理、配置、隐私、头像或权限展示逻辑。

## 当前状态

- 已按用户要求将“投喂一下”改为仅触发 `UIImpactFeedbackGenerator` 震动。
- 已移除不再使用的赞赏弹窗/赞赏扫码实现：`UI/YZRewardView.h`、`UI/YZRewardView.m`、`UI/YZDonationImageProvider.m`，并从 `Makefile` 移除对应编译项。
- 已增强微信服务定位：`YZWCRuntime getService:` 会在 `MMServiceCenter defaultCenter` 失败时尝试 `MMContext activeUserContext -> serviceCenter`。
- 已增强公众号关注判断：优先读取 `isContact`、`isInContactList`、`isInContact`、`isFriend` 等状态，减少仅凭联系人对象存在造成的误判。
- 已增强自动关注调用：同时兼容传公众号 ID 和传 `CContact/MMContact` 对象的 selector 形态；单个 selector 调用异常时继续尝试后续候选。
- 已增强底部胶囊行为：关注请求发出后延迟复查状态，仍未确认关注时再打开公众号资料页。
- 已修复设备标识：补齐 iPhone 17 系列 `iPhone18,*` 映射，未知新 iPhone/iPad/iPod 型号改为显示泛称加硬件标识。
- 已修正底部关注失败兜底：点击底部胶囊仍先调用 `followBrand:` 自动关注；关注请求失败或延迟复查仍未确认关注时，优先在当前定制包进程内打开微信原生资料页，不再调用 `weixin://dl/businessWebview`、`weixin://contacts/profile` 或自建 WKWebView；若资料页也打不开，则复制公众号名称并提示用户搜索关注。
- 已参考用户提供的 `微信助手_3.9-5_无根.deb`：其二进制字符串包含 `initWithMainBrandContact:fromScene:`、`CContactMgr`、`getContactByName:`、`isInContactList:` 等线索，当前已将公众号资料页创建逻辑增强为优先尝试 `initWithMainBrandContact:fromScene:`、`initWithContact:fromScene:`、`initWithContact:`，再回退 setter 注入。
- 已修正原生资料页打开条件：旧逻辑要求同时存在 `contact` 和 `pushNav` 才创建资料页，底部胶囊弹层可能没有 `navigationController` 导致直接复制；当前改为有 `contact` 即创建资料页，若无可 push 导航则用 `UINavigationController` 包装后从当前弹层 present。
- 已参考开源仓库 `itenfay/WeChat_tweak`：其历史公众号关注示例使用 `getContactForSearchByName:` 获取公众号 contact、`addLocalContact:listType:2` 写入本地、`getContactsFromServer:` 同步，再通过 `ContactInfoViewController` + `setM_contact:` 打开资料页；当前已加入这些 selector 和类名兼容。
- 已参考开源仓库 `ways0210/WechatEnhance`：其资料页跳转逻辑会先关闭当前弹窗，再重新获取顶层控制器，能拿到导航控制器就 push `ContactInfoViewController`，否则直接 present；当前已按该模式替换底部胶囊无导航时的展示方式。
- 已按用户要求暂停并移除“小游戏”功能：删除小游戏 hook 源码、编译项、常用功能菜单入口和开关逻辑，当前集中处理公众号关注链路。
- 已修正公众号关注状态误判：`isBrandFollowing:` 优先调用 `CContactMgr isInContactList:`/`isInContact:`/`isMyContact:`；若微信版本没有这些 selector，才读取 contact 的明确列表状态字段；不再因 contact 对象存在或用户名为空而显示“已关注”。
- 用户补充的大佬插件录屏/截图显示 mp 主页可在微信原生 WebView 内打开，UA 含 `MicroMessenger/8.0.74`，页面报“操作频繁，请稍后再试”更像微信服务端频控；当前已新增 `MMWebViewController`/`WCWebViewController` 内部 WebView 兜底打开公众号主页 URL。
- 用户补充正常微信号打开大佬公众号的调试截图：Network 里 `action=urlcheck` 携带 `__biz`、`scene=124`、`url_list`，响应 `base_resp.ret=0` 且 `is_ok=true`，证明微信内部 WebView 会走 A8Key/urlcheck，是当前主页兜底的正确通道。
- 已收紧底部胶囊展示流程：若从 `YZGlassSheetController` 插件弹层触发，先关闭弹层，再 push 微信原生资料页或内部 WebView，避免页面被插件弹层挡住导致看起来“没跳转”。
- 用户真机反馈：受限微信号点击底部后能进入公众号主页，但返回后底栏由“未关注”变为“已关注”；同时主页只有“发送消息”没有关注按钮。当前已调整为优先打开微信内部 WebView 的 mp 主页，并移除打开主页链路中的 `addLocalContact:listType:`、`getContactsFromServer:`、`addBrandContact:scene:` 等本地 contact 写入/刷新动作，避免污染关注状态。
- 已恢复“常用功能”空壳入口：主菜单保留“常用功能”，子页仅显示“暂无功能”，不包含小游戏或任何开关。
- 已同步 `control`、`README.md`、`Core/YZConfigManager.m`、`Core/YZPluginLifecycle.m`、`Guard/YZPrivacyGuard.m`、`preview.html` 到版本 `1.1.6`。

## 下一步

- 推送后等待 GitHub Actions 构建结果。
- 真机验证首次弹窗倒计时、确认按钮、自动关注请求、失败提示，以及底部胶囊失败后是否留在定制包内打开原生资料页；若无法打开，应只复制公众号名称并提示搜索，不再显示“请在微信客户端打开链接”。
- 当前重点验证：未关注/受限账号在插件底部是否不再误显示“已关注”；点击底部关注后，原生资料页失败时是否进入微信内部 WebView 的公众号主页，而不是外跳官方微信或自建 WKWebView。
- 继续重点验证：进入公众号主页再返回后，底栏是否仍保持“未关注”；常用功能入口是否存在且为空壳。
- 用户当前测试微信账号功能受限，关注成功与否需要正常账号客户或解除限制后最终确认。

## 验证方式

- 已运行 `git diff --check`，无空白错误。
- 已搜索活跃代码，未发现旧赞赏弹窗/旧赞赏扫码 provider/`1.1.1`/“跳转微信打赏页”残留。
- 本机 Windows 当前未检测到 `make`、`clang`、`dpkg-deb`，无法本地完成 Theos 编译验证；需以 GitHub Actions 为构建验证。
