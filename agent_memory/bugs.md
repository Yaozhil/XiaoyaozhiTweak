# 问题与风险

## 已知问题

- 之前 `1.2.5` 候选只触发隐藏扫码，缺少 WCRefine 的“非相册来源”修正，容易卡在微信扫码结果处理链路。
- `UI/YZDonationImageProvider.m` 曾内嵌旧赞赏码，可能导致扫描的不是用户当前赞赏码。

## 风险与待确认

- 新 hook 基于成熟插件静态逆向复刻，仍需真机验证微信版本兼容性。
- 私有 ivar `_bIsScanFromAlbumImage` 与 `_picFrom` 可能随微信版本变化；当前实现用运行时查找并用赞赏扫描窗口限制影响范围。
- Windows 本机缺少 Theos/make/clang/dpkg-deb，WSL 未安装可用发行版，未完成编译级验证。

## 失败尝试

- 本地通用二维码解码库无法解出微信赞赏码内容，说明不能简单拿到 `wxpay://` 或 native URL 绕过微信扫码结果处理。
- 直接复刻 `scanOnePicture:` 触发不足以稳定进入赞赏页。
