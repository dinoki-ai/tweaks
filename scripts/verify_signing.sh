#!/usr/bin/env bash
set -euo pipefail

echo "Verifying Tweaks app (ARM64)..."
codesign -vvv --deep --strict "build_output/tweaks.app"

echo "Checking Sparkle framework (ARM64)..."
if [ -f "build_output/tweaks.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" ]; then
  codesign -d --entitlements - "build_output/tweaks.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" 2>&1 | grep -q "<dict/>" && echo "✅ Sparkle has no entitlements" || echo "⚠️ Sparkle might have entitlements"
else
  echo "ℹ️ Sparkle.framework not found in app bundle (skipping check)"
fi
