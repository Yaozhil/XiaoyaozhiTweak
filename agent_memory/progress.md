# 当前任务进度

## 当前状态

- 公众号入口与自动关注排查已归档：`agent_memory/archive/2026-06-12-official-account-route.md`。
- 本地 `main` 与远端 `origin/main` 已同步到本次“投喂一下”打赏跳转与短日志改动。
- 最近一次 GitHub Actions 构建成功：https://github.com/Yaozhil/XiaoyaozhiTweak/actions/runs/27398531114
- 用户已确认：底部胶囊跳转公众号主页正常，返回后插件功能列表正常。
- 当前正在完善“投喂一下”：目标是点击后直接进入微信打赏页，且失败时留下明确运行日志。
- 用户真机反馈“投喂一下”点击显示失败，日志确认为 `最近打赏路由: failed:no-image`，说明安装后未能从文件路径读取打赏码。

## 已完成

- 插件公开版本保持 `1.0.8`。
- 首次弹窗“已知晓”后自动关注保留，当前可命中品牌号关注 selector。
- 底部胶囊使用 `richtext:synthetic` 打开公众号主页。
- 已确认关注时点击底部胶囊提示 `已关注公众号`；无法确认时仍按“去关注”入口处理。
- 运行日志入口可复制本地反馈，用于后续真机排查。
- 已避开文件传输助手消息、WebView/A8Key/AppDelegate/外部 scheme、全类扫描等高风险路线。
- “投喂一下”已接入安装包内打赏码加载与微信 `ScanQRCodeLogicController scanOnePicture:` 路线；运行反馈新增“最近打赏路由”。
- 运行日志已改为短滚动：复制反馈只包含最近 40 条，单行会截断，避免历史功能日志过长导致无法复制。
- 已新增内嵌打赏码 provider：优先读取安装包文件，缺失时回落到 dylib 内嵌图片，避免签名/安装流程漏掉 `layout/` 资源后直接 `no-image`。

## 下一步

- 等待 GitHub Actions 构建结果。
- 真机复测“投喂一下”，重点看 `donation.open.image {"source":"embedded"}` 后是否继续出现 `donation.open.hit`。

## 验证

- 最近构建：GitHub Actions `Build rootless deb` 成功。
- 本次本地检查：`git diff --check` 通过；敏感路线扫描未命中。
