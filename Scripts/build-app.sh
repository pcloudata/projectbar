#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/dist/ProjectBar.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN_DIR/ProjectBar" "$MACOS/ProjectBar"
cp "$BIN_DIR/projectbar-ingest" "$MACOS/projectbar-ingest"
cp "$ROOT/Sources/ProjectBar/Info.plist" "$CONTENTS/Info.plist"

# Install ingest CLI for hooks
mkdir -p "$HOME/.local/bin"
cp "$BIN_DIR/projectbar-ingest" "$HOME/.local/bin/projectbar-ingest"
chmod +x "$HOME/.local/bin/projectbar-ingest"
chmod +x "$MACOS/ProjectBar" "$MACOS/projectbar-ingest"

echo "Built $APP_DIR"
echo "CLI installed to ~/.local/bin/projectbar-ingest"
echo "Run: open \"$APP_DIR\""
