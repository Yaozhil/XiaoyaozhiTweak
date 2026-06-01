#!/bin/zsh
set -euo pipefail

# ============================================================
# 小杳知插件构建脚本 (macOS + Theos)
# ============================================================

export THEOS="${THEOS:-/opt/theos}"
export THEOS_PACKAGE_SCHEME=rootless

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo "  小杳知 · iOS 26 液态风格插件构建"
echo "  Target: arm64 / arm64e (rootless)"
echo "========================================="

# 清理
rm -rf .theos packages
mkdir -p packages

# 构建
echo "[1/3] 编译..."
make clean
make package FINALPACKAGE=1

# 收集产物
echo "[2/3] 收集构建产物..."
LATEST_DEB="$(ls -t packages/*.deb 2>/dev/null | head -n 1 || true)"
if [[ -z "$LATEST_DEB" ]]; then
    echo "错误: 未找到 .deb 包"
    exit 1
fi

VERSION="$(sed -n 's/^Version: *//p' control | head -n 1)"
VERSION_SAFE="${VERSION//-/_}"
FINAL_NAME="XiaoyaozhiTweak_v${VERSION_SAFE}_rootless.deb"

cp "$LATEST_DEB" "$PROJECT_DIR/$FINAL_NAME"
echo "  ✅ Deb: $PROJECT_DIR/$FINAL_NAME"

# 提取 dylib
BUILT_DYLIB="$(find .theos -name "XiaoyaozhiTweak.dylib" -type f 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "$BUILT_DYLIB" ]]; then
    cp "$BUILT_DYLIB" "$PROJECT_DIR/XiaoyaozhiTweak.dylib"
    echo "  ✅ Dylib: $PROJECT_DIR/XiaoyaozhiTweak.dylib"
fi

# 生成隐私报告
echo "[3/3] 生成隐私报告..."
PRIVACY_REPORT="$PROJECT_DIR/privacy_report.txt"
cat > "$PRIVACY_REPORT" << 'PREOF'
小杳知插件 · 隐私合规声明
===========================

✅ 不访问 相册 (PHPhotoLibrary)
✅ 不访问 通讯录 (CNContactStore)
✅ 不访问 定位 (CLLocationManager)
✅ 不访问 麦克风 (AVAudioSession)
✅ 不访问 相机 (AVCaptureDevice)
✅ 不访问 蓝牙 (CBCentralManager)
✅ 不访问 日历 (EKEventStore)
✅ 不访问 健康 (HKHealthStore)
✅ 不访问 Keychain
✅ 不发起网络请求
✅ 仅使用 NSUserDefaults (沙盒内)

数据存储范围: 微信沙盒 / NSUserDefaults (com.rouneed.xiaoyaozhi)
第三方 SDK: 无
PREOF

echo "  ✅ 隐私报告已生成"

echo ""
echo "========================================="
echo "  ✅ 构建完成!"
echo "  产品: $FINAL_NAME"
echo "========================================="
