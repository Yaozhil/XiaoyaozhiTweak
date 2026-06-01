# 小杳知 / XiaoyaozhiTweak

基于 Theos 的 rootless 微信增强插件项目。

## 版本

- Package: `com.rouneed.xiaoyaozhi`
- Version: `1.1.0`
- Target: `iphoneos-arm64`
- Minimum iOS: `14.0`

## 上传到 GitHub

1. 在 GitHub 新建一个空仓库。
2. 在本目录执行：

```powershell
git remote add origin https://github.com/<你的用户名>/<你的仓库名>.git
git push -u origin main
```

如果远端已存在，先检查：

```powershell
git remote -v
```

## 自动生成 deb

仓库内置 GitHub Actions：`.github/workflows/build-deb.yml`。

推送到 `main` 或 `master` 后会自动构建 rootless deb。也可以在 GitHub 仓库页面手动运行：

1. 打开仓库的 `Actions`
2. 选择 `Build rootless deb`
3. 点击 `Run workflow`
4. 构建完成后下载 artifact：`XiaoyaozhiTweak-rootless`

生成的 `.deb` 会在 artifact 中。

## 本地构建（macOS / Theos）

```bash
export THEOS=/opt/theos
make clean
make package FINALPACKAGE=1
```

生成路径：

```text
packages/*.deb
```

Windows 本机通常不直接构建 iOS tweak，推荐使用 GitHub Actions 或 macOS + Theos。
