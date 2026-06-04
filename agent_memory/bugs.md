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
- 新接入的 `BrandDirectlyOperateContactLogic -> tryAddBrandContact:context:` 来自参考插件二进制线索，属于更贴近微信品牌号逻辑的自动关注路径；但上下文字段仍是按可见类名和常见 setter/KVC 保守填充，需要 GitHub Actions 构建和真机验证确认不同微信版本是否命中。
- `followBrand:` 只能可靠判断“关注请求是否已成功发出/selector 是否命中”；微信服务端是否最终完成关注，需要正常账号真机验证。
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
- 用户反馈后续仍黑屏并且返回后全黑，说明通用/品牌资料页 VC push 路线整体会污染微信导航栈；当前底部入口停用私有资料页 VC，改走微信 AppDelegate/Universal Link 内部路由处理 mp 链接。
- 受限账号进入公众号主页只看到“发送消息”、没有关注按钮，可能是微信账号限制或服务端状态导致；插件只能打开正确的微信内部主页，无法绕过微信限制强制关注。
- `WeChat-2026-06-05-004816.ips` 显示底部点击闪退为 `doesNotRecognizeSelector`/`SIGABRT`，触发线程是主线程手势，调用栈经过插件 dylib；高风险点为直接调用微信私有 WebView 构造器或自动关注 selector。当前已禁用 WebView 私有构造，并让底部胶囊不直接调用自动关注私有接口。
- Windows 本机缺少 Theos/make/clang/dpkg-deb，编译级验证依赖 GitHub Actions。

## 失败尝试

- 旧的赞赏扫码直达链路曾多次导致卡死或黑屏，当前已完全退出产品路径。
