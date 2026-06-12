# 项目上下文

## 项目概览

- 项目是小杳知微信增强插件，当前工作目录为 `C:\Users\杳知\Desktop\XiaoyaozhiTweak_v1.0.1`。
- 当前主线目标是：公众号关注入口稳定可靠，不闪退、不误报已关注；首次弹窗可尝试自动关注，底部胶囊提供微信内公众号主页入口；“投喂一下”通过安装包内打赏码走微信原生扫码识别链路打开打赏页，不展示旧赞赏弹窗。

## 关键约定

- 默认中文沟通，代码命名保持仓库原有 Objective-C/Logos 风格。
- 非简单任务先读相关文件，再做最小范围、可验证的改动。
- 版本号按用户要求保持 `1.0.8`，后续除非用户明确要求递增，否则不再自动改版本号。

## 重要文件与入口

- `XiaoyaozhiTweak.xm`：Logos hook 集中入口；负责首次倒计时弹窗、安装指纹检测、弹窗确认后的自动关注。
- `UI/YZGlassSheetController.m`：插件主界面；底部关注胶囊、投喂入口点击、toast 位置等 UI 行为。
- `WeChat/YZWCServiceCenter.m`：微信私有服务桥接；负责检测公众号关注状态、发起关注请求、公众号主页兜底和打赏码扫码跳转。底部主页入口当前只调用固定白名单里的高层 URL/Link router，不走 AppDelegate/Universal Link，不直接构造/push `MMWebViewController/WCWebViewController`，不动态枚举 Web/WebView/load/jump selector。
- `WeChat/YZWCServiceCenter.m`：自动关注当前优先参考 `WCEhance/WCPulse` 中出现的 `BrandDirectlyOperateContactLogic -> tryAddBrandContact:context:`，失败再回退老的联系人/品牌号 selector。
- `WeChat/YZWCServiceCenter.m`：同时负责设备型号识别，当前已补齐 iPhone 17 系列 `iPhone18,*` 映射，未知新机型回退显示硬件标识。
- `WeChat/YZWCRuntime.m`：微信服务定位；当前会先走 `MMServiceCenter defaultCenter`，失败后兜底到 `MMContext activeUserContext -> serviceCenter`。
- `UI/YZFollowIconProvider.m`：内嵌左下角关注图标。

## 已确认假设

- 用户当前不需要展示赞赏弹窗；“投喂一下”应尽量直达打赏页，当前最小方案是复用安装包里的 `reward_qr.png`/`donation.png`，调用微信 `ScanQRCodeLogicController scanOnePicture:`，不 present 私有扫码控制器。
- 首次弹窗必须等待当前微信账号可检测到后再展示，避免未登录时提前标记已展示。
- 首次弹窗的自动关注失败时只提示失败；确认按钮会调用 `YZWCServiceCenter followBrand:` 尝试自动关注。底部胶囊不直接调用高风险自动关注私有接口；点击后先复制公众号名称兜底，再尝试高层 URL/Link router 打开公众号主页。
- 用户提供公众号主页链接：`https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=Mzk2NDE2MjU5Ng==&scene=124`；因定制包 bundle id 与官方微信不同，禁止在底部胶囊兜底中调用 `weixin://` 外部 scheme，避免跳到官方微信并弹 `invalid_source`；`6af785b` 的 AppDelegate/Universal Link 路由真机黑屏，直接构造/push `MMWebViewController/WCWebViewController` 真机也黑屏，当前两条都禁用。
- 当前关键判断：底部“关注公众号”必须保留点击跳转能力，但不能自己创建 WebView/资料页，不能走 AppDelegate/外部 scheme，也不能动态枚举调用未知微信 URL/Web 分发器；当前只尝试固定白名单里的高层 URL/Link router，命不中时复制公众号名称提示搜索。
