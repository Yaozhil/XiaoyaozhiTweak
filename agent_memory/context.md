# 项目上下文

## 项目概览

- 项目是小杳知微信增强插件，当前工作目录为 `C:\Users\杳知\Desktop\XiaoyaozhiTweak_v1.0.1`。
- 本轮目标是修复“投喂一下”直达微信真实赞赏页卡死问题，并同步用户当前赞赏码/左下角图标。

## 关键约定

- 默认中文沟通，代码命名保持仓库原有 Objective-C/Logos 风格。
- 非简单任务先读相关文件与成熟插件行为，再做最小范围改动。
- 用户明确要求：需要新资料时主动询问，不要盲目开工。

## 重要文件与入口

- `UI/YZRewardView.m`：赞赏入口、赞赏码加载、隐藏扫码触发。
- `XiaoyaozhiTweak.xm`：Logos hook 集中入口；1.2.7 已移除上一版赞赏扫码来源 hook。
- `UI/YZFollowIconProvider.m`：内嵌左下角关注图标。
- `UI/YZDonationImageProvider.m`：内嵌赞赏码图片。
- `Resources/reward_qr.png` 与 `layout/Library/...`：安装包内赞赏码资源。

## 已确认假设

- WCEhance 的“打赏作者”链路会调用 `ScanQRCodeLogicParams`、`ScanQRCodeLogicController`、`ScanQRCodeResultsMgr`、`NewQRCodeScannerParams`、`NewQRCodeScanner`。
- WCEhance 获取 `ScanQRCodeResultsMgr` 的路径是 `MMContext activeUserContext -> serviceCenter -> getService:`，不是优先走 `MMServiceCenter defaultCenter`。
- WCEhance 的打赏链路没有出现 `scanFromAlbum`、`_bIsScanFromAlbumImage`、`_picFrom`、`openQRCodeOrWXCodeLandingPage...` hook。
- 用户提供的 `C:\Users\杳知\Desktop\赞赏码.png` 与仓库 `Resources/reward_qr.png` 哈希一致，但文件实际是 JPEG 数据。
- WCPulse 主要展示赞赏码，不是直达微信赞赏页的主要参考。
