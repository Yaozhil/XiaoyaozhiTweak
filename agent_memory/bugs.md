# 问题与风险

## 已知问题

- 用户真机反馈：点击“投喂一下”曾直接黑屏；原因指向菜单入口 present 微信私有扫码控制器后未成功跳转。当前已按用户要求移除所有可见赞赏行为，仅保留震动。
- 用户真机反馈：停在功能列表长时间不动曾导致微信闪退；此前高风险点是菜单页后台线程调用微信私有 `CContactMgr`/头像获取链路，已收回主线程并移除异步头像刷新。
- 用户测试微信账号处于功能受限状态，无法作为公众号自动关注成功与否的最终验证样本。
- 底部关注失败兜底曾只提示“请手动搜索关注”，原因是 `openBrandProfile` 过度依赖 `CContactMgr`/本地联系人对象；后续调用 `weixin://dl/businessWebview` 会因定制包 bundle id 不同而跳到官方微信并弹 `invalid_source`，自建 WKWebView 又会显示“请在微信客户端打开链接”。当前已移除外部 scheme 和 WKWebView 兜底，原生资料页打不开时复制公众号名称提示搜索。
- 底部胶囊曾只显示“已复制公众号名称，请搜索关注”，新增判断显示原因可能是 `viewController.navigationController` 和微信根导航均未命中，旧代码因此完全跳过资料页创建；当前已增加无 pushNav 时的 present 兜底。
- 17 系列设备曾因 `iPhone18,*` 未映射而只显示 `iPhone`，已补齐映射并优化未知机型回退。

## 风险与待确认

- 公众号自动关注依赖微信私有 `CContactMgr`/品牌号相关 selector；已扩大兼容候选并加入 `CContact/MMContact` 参数兜底，但不同微信版本仍可能变更 selector 或内部校验。
- `followBrand:` 只能可靠判断“关注请求是否已成功发出/selector 是否命中”；微信服务端是否最终完成关注，需要正常账号真机验证。
- `isBrandFollowing:` 已优先读取联系人状态 selector；若某微信版本完全不暴露关注状态，只能回退到联系人对象存在这一保守兼容判断。
- 参考插件 `com.shtm.xos_1.4.5_iphoneos-arm64e.deb` 为 `data.tar.lzma`，当前 Windows 环境缺少 lzma/xz 工具，暂未能读取内部动态库；`微信助手_3.9-5_无根.deb` 可读取并已提取 selector 线索。
- `itenfay/WeChat_tweak` 的公众号关注代码年代较早且在当前仓库文件中是注释/历史示例，selector 兼容性仍需真机验证；已只提取最小兼容思路，没有引入网页或外部 scheme。
- `ways0210/WechatEnhance` 未包含自动关注公众号实现，但其 `NavigationTitleHooks.xm` 有可用的 `ContactInfoViewController` 跳转模式：关闭弹窗后重新获取顶层控制器再 push/present，当前已采用。
- “小游戏”来源于 `ways0210/WechatEnhance` 的 `GameCheatsHook.xm` 思路，依赖微信 `CMessageMgr`、`CMessageWrap`、`GameController getMD5ByGameContent:` 等私有接口；不同微信版本可能变更游戏消息字段或 MD5 映射，需要真机验证。
- Windows 本机缺少 Theos/make/clang/dpkg-deb，编译级验证依赖 GitHub Actions。

## 失败尝试

- 旧的赞赏扫码直达链路曾多次导致卡死或黑屏，当前已完全退出产品路径。
