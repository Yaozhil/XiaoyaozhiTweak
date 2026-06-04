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
- 已同步 `control`、`README.md`、`Core/YZConfigManager.m`、`Core/YZPluginLifecycle.m`、`Guard/YZPrivacyGuard.m`、`preview.html` 到版本 `1.1.6`。

## 下一步

- 推送后等待 GitHub Actions 构建结果。
- 真机验证首次弹窗倒计时、确认按钮、自动关注请求、失败提示，以及底部胶囊失败后是否留在定制包内打开原生资料页；若无法打开，应只复制公众号名称并提示搜索，不再显示“请在微信客户端打开链接”。
- 用户当前测试微信账号功能受限，关注成功与否需要正常账号客户或解除限制后最终确认。

## 验证方式

- 已运行 `git diff --check`，无空白错误。
- 已搜索活跃代码，未发现旧赞赏弹窗/旧赞赏扫码 provider/`1.1.1`/“跳转微信打赏页”残留。
- 本机 Windows 当前未检测到 `make`、`clang`、`dpkg-deb`，无法本地完成 Theos 编译验证；需以 GitHub Actions 为构建验证。
