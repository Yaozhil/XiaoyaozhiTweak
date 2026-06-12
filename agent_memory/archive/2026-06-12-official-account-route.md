# 2026-06-12 公众号入口与自动关注归档

## 最终状态

- 插件版本保持 `1.0.8`。
- 首次弹窗“已知晓”后自动关注链路已恢复，当前真机日志可见 `BrandDirectlyOperateContactLogic tryAddBrandContact:context:` 命中，`auto_follow.result {"sent":true}`。
- 底部胶囊已可通过 `richtext:synthetic` 跳转到公众号主页。
- 用户最终确认：底部胶囊跳转公众号主页、返回后功能列表可点，整体正常。
- 已确认关注时点击底部胶囊显示 `已关注公众号`；无法确认 `-1` 时仍显示/作为“去关注”入口。
- 主菜单“运行日志”可复制本地运行反馈，便于后续排查。

## 关键实现

- `WeChat/YZWCServiceCenter.m`
  - 保留固定公众号主页 URL：`https://mp.weixin.qq.com/mp/profile_ext?action=home&__biz=Mzk2NDE2MjU5Ng==&scene=124`。
  - 高层 URL router 不可用时，使用临时 `RichTextView` 写入固定链接并调用微信原生 `clickOnLinkEvent:`。
  - 不发送消息、不写文件传输助手、不读聊天内容、不记录 URL 明文、不调用 WebView/A8Key/AppDelegate/外部 scheme。
  - 删除 `richtext` 命中后的 `sheet.dismiss`，避免公众号页返回后底层插件页被禁用触摸。
- `UI/YZGlassSheetController.m`
  - `followState == 1` 时点击底部胶囊 toast `已关注公众号` 并返回。
  - `presentInWindow:` 显式恢复 `self.view.userInteractionEnabled = YES`。
  - “运行日志”复制报告保留最近路由、关注状态、环境和本地日志。

## 已踩坑路线

- 外部 `weixin://` 会跳官方微信或触发 `invalid_source`，禁止恢复。
- AppDelegate/Universal Link 路由曾导致黑屏，禁止恢复。
- 直接构造或 present `MMWebViewController/WCWebViewController` 曾黑屏，禁止恢复。
- 直接调用 `WebViewA8KeyLogicImpl goToURL:withCustomerCookies:` 在 `hasUrlPermission=false` 后闪退，禁止恢复。
- `objc_getClassList` 全类扫描曾导致点击后闪退，禁止恢复。
- `CMessageWrap/AddMsg` 发到 `filehelper` 可命中但会产生客户可见消息，体验像账号异常，禁止作为客户版入口。
- “先 dismiss 插件再触发 synthetic RichTextView”真机会重新黑屏，禁止恢复。
- `richtext` 命中后再 `sheet.dismiss` 会导致公众号页返回后插件列表无法点击，禁止恢复。

## 最终提交

- `b5e12c9 keep sheet active after rich text route`
- GitHub Actions 成功：https://github.com/Yaozhil/XiaoyaozhiTweak/actions/runs/27398531114

## 后续注意

- `brandFollowState` 在微信 8.0.74 上仍可能返回 `-1`，这是微信不稳定暴露关注状态导致；不要把 `contact` 存在当作已关注。
- 自动关注只能判断请求 selector 是否命中/发出，最终是否服务端关注成功仍以真机账号状态为准。
- 后续继续保持版本号单源/校验规则：公开版本仍为 `1.0.8`，除非用户明确要求递增。
