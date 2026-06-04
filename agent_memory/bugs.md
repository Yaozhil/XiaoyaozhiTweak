# 问题与风险

## 已知问题

- 之前 `1.2.5` 候选只触发隐藏扫码，缺少 WCRefine 的“非相册来源”修正，容易卡在微信扫码结果处理链路。
- `UI/YZDonationImageProvider.m` 曾内嵌旧赞赏码，可能导致扫描的不是用户当前赞赏码。
- `1.2.6` 真机点击“投喂一下”会卡住界面但不闪退；推测原因是按 WCRefine 增加的扫码来源 hook 与当前上下文链路不匹配，且 `ScanQRCodeResultsMgr` 获取方式不符合 WCEhance 的成功路径。
- 功能菜单上下滑动偶发卡顿，代码层面已发现并处理：权限状态点曾为每个 cell 创建无限动画，切页 reload 曾强制同步 `layoutIfNeeded`，全部权限名称曾在 cell 渲染时重复排序。
- Actions 在 Xcode 16.4 / iOS 18.5 SDK 下将 `UIApplication.keyWindow` 弃用警告作为错误处理，导致 `UI/YZRewardView.m` 编译失败；项目最低系统为 iOS 14，已改为直接走 `connectedScenes`，必要时回退到 app delegate 的 `window`。
- 用户真机反馈：1.2.7 点击“投喂一下”仍会卡死；已发现当前实现与 WCEhance 的差异是 host controller 不是当前页面，且扫描输入曾使用整张赞赏海报。
- 用户真机反馈：停在功能列表长时间不动会导致微信闪退；高风险点是菜单页后台线程调用微信私有 `CContactMgr`/头像获取链路，已收回主线程并移除异步头像刷新。
- 用户反馈左下角透明图标缺块；原因是上一版抠图策略过激，已改为只移除边缘连通的近纯白背景。

## 风险与待确认

- 1.2.7 改为 WCEhance 风格后仍需真机验证微信版本兼容性。
- 真实赞赏页链路依赖微信私有扫码类，类名或 selector 随微信版本变化时仍可能失效。
- Windows 本机缺少 Theos/make/clang/dpkg-deb，WSL 未安装可用发行版，未完成编译级验证。
- 公众号自动关注依赖微信私有 `CContactMgr`/品牌号相关 selector；代码只能按 selector 是否命中判断请求是否发出，真机仍需确认微信版本是否真正完成关注。

## 失败尝试

- 本地通用二维码解码库无法解出微信赞赏码内容，说明不能简单拿到 `wxpay://` 或 native URL 绕过微信扫码结果处理。
- 直接复刻 `scanOnePicture:` 触发不足以稳定进入赞赏页。
- 按 WCRefine 复刻扫码来源 hook 的 `1.2.6` 仍会卡住界面；当前已改按 WCEhance 的上下文服务中心路径继续验证。
