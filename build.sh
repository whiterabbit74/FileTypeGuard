#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$SCRIPT_DIR/FileTypeGuard.xcodeproj"
SCHEME="FileTypeGuard"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$SCRIPT_DIR/build}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild is required. Install Xcode command line tools."
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: project not found at $PROJECT_PATH"
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/FileTypeGuard.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: build finished, but app bundle not found at $APP_PATH"
  exit 1
fi

echo "Build succeeded: $APP_PATH"
