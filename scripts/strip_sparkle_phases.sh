#!/usr/bin/env bash
# Strip unused architectures from Sparkle framework
# This script should be added as a build phase in Xcode

set -e

# Only process for release builds
if [ "${CONFIGURATION}" != "Release" ]; then
    echo "Skipping Sparkle strip for ${CONFIGURATION} configuration"
    exit 0
fi

# Path to Sparkle framework
SPARKLE_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sparkle.framework"

if [ ! -d "$SPARKLE_PATH" ]; then
    echo "Sparkle framework not found at: $SPARKLE_PATH"
    exit 0
fi

echo "Stripping unused architectures from Sparkle..."

# Find all architectures
ARCHS=$(lipo -info "${SPARKLE_PATH}/Sparkle" | rev | cut -d ':' -f1 | rev)

# Strip non-active architectures
for ARCH in $ARCHS; do
    if [[ "$VALID_ARCHS" != *"$ARCH"* ]]; then
        echo "Stripping $ARCH from Sparkle"
        lipo -remove "$ARCH" -output "${SPARKLE_PATH}/Sparkle" "${SPARKLE_PATH}/Sparkle" || exit 1
    fi
done

echo "✅ Sparkle architecture stripping complete"
