#!/bin/bash
set -euo pipefail

# Build script for GitHub Review Manager without Xcode
# Requires: Swift toolchain installed

PRODUCT_NAME="GitHubReviewManager"
BUNDLE_NAME="${PRODUCT_NAME}.app"
BUNDLE_ID="com.github-review-manager.app"
SOURCE_DIR="GitHubReviewManager"
BUILD_DIR=".build"
APP_BUNDLE="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building ${PRODUCT_NAME}..."

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compile all Swift files
echo "Compiling Swift sources..."
find "${SOURCE_DIR}" -name "*.swift" -type f | while read -r swift_file; do
    echo "  - $(basename "${swift_file}")"
done

# Compile with swiftc
# Get SDK path (works with or without full Xcode)
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")

# Find all Swift files
SWIFT_FILES=$(find "${SOURCE_DIR}" -name "*.swift" -type f | tr '\n' ' ')

echo "Compiling Swift files..."

# Detect architecture (arm64 or x86_64)
ARCH=$(uname -m)
if [ "${ARCH}" = "arm64" ]; then
    TARGET="arm64-apple-macosx12.0"
else
    TARGET="x86_64-apple-macosx12.0"
fi

swiftc \
    -sdk "${SDK_PATH}" \
    -target "${TARGET}" \
    ${SWIFT_FILES} \
    -o "${MACOS_DIR}/${PRODUCT_NAME}" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    -framework Combine

# Create Info.plist (replace template variables if copying from source)
if [ -f "${SOURCE_DIR}/Resources/Info.plist" ]; then
    sed "s/\$(EXECUTABLE_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${BUNDLE_ID}/g; s/\$(DEVELOPMENT_LANGUAGE)/en/g; s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g; s/\$(MACOSX_DEPLOYMENT_TARGET)/12.0/g" "${SOURCE_DIR}/Resources/Info.plist" > "${CONTENTS_DIR}/Info.plist"
elif [ -f "${SOURCE_DIR}/Info.plist" ]; then
    sed "s/\$(EXECUTABLE_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${BUNDLE_ID}/g; s/\$(DEVELOPMENT_LANGUAGE)/en/g; s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g; s/\$(MACOSX_DEPLOYMENT_TARGET)/12.0/g" "${SOURCE_DIR}/Info.plist" > "${CONTENTS_DIR}/Info.plist"
elif [ -f "GitHubReviewManager/Info.plist" ]; then
    sed "s/\$(EXECUTABLE_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_NAME)/${PRODUCT_NAME}/g; s/\$(PRODUCT_BUNDLE_IDENTIFIER)/${BUNDLE_ID}/g; s/\$(DEVELOPMENT_LANGUAGE)/en/g; s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g; s/\$(MACOSX_DEPLOYMENT_TARGET)/12.0/g" "GitHubReviewManager/Info.plist" > "${CONTENTS_DIR}/Info.plist"
else
    echo "Warning: Info.plist not found, creating minimal one..."
    cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
fi

# Copy icon if available (try multiple locations)
ICON_COPIED=false
if [ -f "../assets/icon.png" ]; then
    cp "../assets/icon.png" "${RESOURCES_DIR}/icon.png"
    echo "Copied icon from ../assets/icon.png"
    ICON_COPIED=true
elif [ -f "assets/icon.png" ]; then
    cp "assets/icon.png" "${RESOURCES_DIR}/icon.png"
    echo "Copied icon from assets/icon.png"
    ICON_COPIED=true
elif [ -f "${SOURCE_DIR}/Resources/icon.png" ]; then
    cp "${SOURCE_DIR}/Resources/icon.png" "${RESOURCES_DIR}/icon.png"
    echo "Copied icon from ${SOURCE_DIR}/Resources/icon.png"
    ICON_COPIED=true
fi

if [ "$ICON_COPIED" = false ]; then
    echo "Warning: icon.png not found in any expected location"
fi

# Create PkgInfo (optional but sometimes needed)
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Code sign with ad-hoc signature (required for macOS to run)
echo "Code signing app..."
codesign --deep --force --sign - "${APP_BUNDLE}" 2>&1 || {
    echo "Warning: Code signing failed, but app should still work"
}

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "If macOS blocks it, right-click and select 'Open', or run:"
echo "  xattr -cr ${APP_BUNDLE} && open ${APP_BUNDLE}"

