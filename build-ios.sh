#!/bin/bash
#
# MobileGlues iOS 构建脚本
#
# 产出：plugin/libs/libMobileGlues.dylib  +  plugin/MobileGlues.air2plugin
#
# 前置：
#   · macOS + Xcode（需要 iphoneos SDK）
#   · cmake >= 3.20
#
# 用法：
#   ./build-ios.sh                 # 构建 arm64
#   ./build-ios.sh --simulator     # 构建模拟器版（调试用）
#   ./build-ios.sh --package       # 构建后自动打包成 .air2plugin
#

set -e

# ---------- 参数 ----------
SIMULATOR=0
PACKAGE=0
for arg in "$@"; do
    case "$arg" in
        --simulator) SIMULATOR=1 ;;
        --package)   PACKAGE=1 ;;
        *) echo "未知参数: $arg"; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build-ios"
PLUGIN_DIR="$ROOT/plugin"
MIN_IOS="14.0"

# ---------- 环境检查 ----------
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    echo "错误：找不到 iphoneos SDK，请在 macOS + Xcode 环境下运行"
    exit 1
fi

if [ "$SIMULATOR" = "1" ]; then
    SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
    SYSROOT_NAME="iphonesimulator"
    ARCHS="arm64;x86_64"
    echo "==> 构建模拟器版（$ARCHS）"
else
    SDK=$(xcrun --sdk iphoneos --show-sdk-path)
    SYSROOT_NAME="iphoneos"
    ARCHS="arm64"
    echo "==> 构建真机版（arm64）"
fi

echo "    SDK: $SDK"
echo "    最低 iOS: $MIN_IOS"

# ---------- 配置 ----------
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$ROOT/MobileGlues-cpp" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
    -G "Unix Makefiles"

# ---------- 构建 ----------
cmake --build . --config Release --parallel

# ---------- 收集产物 ----------
echo ""
echo "==> 收集产物"
mkdir -p "$PLUGIN_DIR/libs"

FOUND=""
for candidate in \
    "$BUILD_DIR/libmobileglues.dylib" \
    "$BUILD_DIR/MobileGlues-cpp/libmobileglues.dylib" \
    "$BUILD_DIR/Release/libmobileglues.dylib"
do
    if [ -f "$candidate" ]; then
        FOUND="$candidate"
        break
    fi
done

if [ -z "$FOUND" ]; then
    # 兜底：全局找一次
    FOUND=$(find "$BUILD_DIR" -name "*.dylib" -type f | head -1)
fi

if [ -z "$FOUND" ]; then
    echo "错误：构建成功但找不到 .dylib 产物"
    echo "请检查 CMakeLists.txt 里的 add_library 输出名"
    exit 1
fi

echo "    找到: $FOUND"
cp "$FOUND" "$PLUGIN_DIR/libs/libMobileGlues.dylib"

# 确认架构
echo ""
echo "==> 架构检查"
lipo -info "$PLUGIN_DIR/libs/libMobileGlues.dylib"

# ---------- 签名 ----------
# ad-hoc 签名 —— TrollStore / 越狱环境可直接加载。
# 正规分发请改成自己的证书身份。
echo ""
echo "==> 签名（ad-hoc）"
codesign -f -s - --timestamp=none "$PLUGIN_DIR/libs/libMobileGlues.dylib" 2>/dev/null || \
    echo "    ⚠️ codesign 失败（不影响 TrollStore 环境）"

codesign -dv "$PLUGIN_DIR/libs/libMobileGlues.dylib" 2>&1 | head -3 || true

# ---------- 打包 ----------
if [ "$PACKAGE" = "1" ]; then
    echo ""
    echo "==> 打包成 .air2plugin"
    cd "$PLUGIN_DIR"
    OUT="$ROOT/MobileGlues.air2plugin"
    rm -f "$OUT"
    zip -r "$OUT" manifest.json libs/ icon.png 2>/dev/null || \
        zip -r "$OUT" manifest.json libs/
    echo "    ✓ $OUT"
    ls -lh "$OUT"
fi

echo ""
echo "==> 完成"
echo "    库:   $PLUGIN_DIR/libs/libMobileGlues.dylib"
[ "$PACKAGE" = "1" ] && echo "    包:   $ROOT/MobileGlues.air2plugin"
echo ""
echo "下一步：在 Air2 里 设置 → 渲染 → 渲染器插件 → 导入插件包"
