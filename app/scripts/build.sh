#!/usr/bin/env bash
# 在 Mac 上构建 / 测试 / 装模拟器。Windows 上无法执行，本文件仅作交付用。
#
# 用法：
#   ./scripts/build.sh                 # 生成工程并编译
#   ./scripts/build.sh test            # 跑单元测试
#   ./scripts/build.sh run             # 编译 + 装到已启动的模拟器并打开
#   ./scripts/build.sh screenshot      # 跑起来并截图到 build/shot.png

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="FuShiZhuan"
PROJECT="FuShiZhuan.xcodeproj"
BUNDLE_ID="com.fushizhuan.app"
SIM_NAME="${SIM_NAME:-iPhone 16}"
DERIVED="build"

log() { printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }

require_mac() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "✗ 这不是 macOS，无法编译 iOS 工程。请把整个 app 目录拷到 Mac 上执行。" >&2
    exit 1
  fi
}

require_mac

# 1. 生成工程
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ 缺少 xcodegen。先执行：brew install xcodegen" >&2
  exit 1
fi
log "生成 Xcode 工程"
xcodegen generate

# 2. 编译
log "编译 $SCHEME"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
echo "✓ 产物：$APP_PATH"

case "${1:-build}" in
  test)
    log "运行测试"
    xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$SIM_NAME" \
      -derivedDataPath "$DERIVED" \
      CODE_SIGNING_ALLOWED=NO \
      test
    ;;

  run|screenshot)
    log "启动模拟器"
    xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
    open -a Simulator

    log "安装并启动"
    xcrun simctl install booted "$APP_PATH"
    xcrun simctl launch booted "$BUNDLE_ID"

    if [[ "${1}" == "screenshot" ]]; then
      sleep 3
      mkdir -p build
      xcrun simctl io booted screenshot build/shot.png
      echo "✓ 截图：build/shot.png"
    fi
    ;;

  build) ;;

  *)
    echo "未知参数：$1" >&2
    exit 1
    ;;
esac

log "完成"
