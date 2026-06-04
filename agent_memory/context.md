# 项目上下文

## 项目概览

- 项目是小杳知微信增强插件，当前工作目录为 `C:\Users\杳知\Desktop\XiaoyaozhiTweak_v1.0.1`。
- 当前主线目标是：公众号关注入口稳定可靠，不闪退、不误报已关注；首次弹窗可尝试自动关注，底部胶囊优先提供安全的手动关注兜底；“投喂一下”只保留震动反馈，不展示赞赏弹窗、不跳转、不 toast。

## 关键约定

- 默认中文沟通，代码命名保持仓库原有 Objective-C/Logos 风格。
- 非简单任务先读相关文件，再做最小范围、可验证的改动。
- 版本号按用户规则从 `1.0.8` 起递增，跳过 `1.1.0` 和 `1.1.4`；当前版本为 `1.1.6`。

## 重要文件与入口

- `XiaoyaozhiTweak.xm`：Logos hook 集中入口；负责首次倒计时弹窗、安装指纹检测、弹窗确认后的自动关注。
- `UI/YZGlassSheetController.m`：插件主界面；底部关注胶囊、投喂入口震动、toast 位置等 UI 行为。
- `WeChat/YZWCServiceCenter.m`：微信私有服务桥接；负责检测公众号关注状态、发起关注请求、打开公众号资料页兜底。
- `WeChat/YZWCServiceCenter.m`：同时负责设备型号识别，当前已补齐 iPhone 17 系列 `iPhone18,*` 映射，未知新机型回退显示硬件标识。
- `WeChat/YZWCRuntime.m`：微信服务定位；当前会先走 `MMServiceCenter defaultCenter`，失败后兜底到 `MMContext activeUserContext -> serviceCenter`。
- `UI/YZFollowIconProvider.m`：内嵌左下角关注图标。

## 已确认假设

- 用户当前不需要展示赞赏弹窗或真实赞赏页直达；旧赞赏扫码/赞赏码 provider 已从构建中移除并删除。
- 首次弹窗必须等待当前微信账号可检测到后再展示，避免未登录时提前标记已展示。
- 首次弹窗的自动关注失败时只提示失败；底部胶囊不直接调用高风险自动关注私有接口，优先打开低风险资料页或复制公众号 ID 供手动关注。
- 用户提供公众号主页链接：`https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=Mzk2NDE2MjU5Ng==&scene=124`；因定制包 bundle id 与官方微信不同，禁止在底部胶囊兜底中调用 `weixin://` 外部 scheme，避免跳到官方微信并弹 `invalid_source`。
