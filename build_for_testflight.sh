#!/bin/bash
# =============================================================================
# GardenPlanner — Build for TestFlight Script
# =============================================================================
# This script:
#   1. Checks your setup (Team ID, certificates, provisioning)
#   2. Builds a Release archive
#   3. Exports an .ipa file for TestFlight upload
#
# Before running:
#   - Open GardenPlanner.xcodeproj in Xcode
#   - Set your DEVELOPMENT_TEAM (Signing & Capabilities tab)
#   - Ensure "Automatically manage signing" is checked

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODE_PROJ="$PROJECT_DIR/GardenPlanner/GardenPlanner.xcodeproj"
OUTPUT_DIR="$PROJECT_DIR/fastlane/output"
BUNDLE_ID="com.josephwoods.GardenPlanner"
APP_NAME="3D Garden Planner"

echo "================================================================"
echo "  GardenPlanner — TestFlight Build"
echo "================================================================"
echo ""

# Check 1: Xcode
echo "📋 Checking Xcode..."
if ! xcodebuild -version > /dev/null 2>&1; then
    echo "❌ Xcode not found. Install Xcode from the Mac App Store."
    exit 1
fi
XCODE_VERSION=$(xcodebuild -version | head -1)
echo "   $XCODE_VERSION"

# Check 2: Project exists
echo ""
echo "📁 Checking project..."
if [ ! -f "$XCODE_PROJ/project.pbxproj" ]; then
    echo "❌ Project not found at $XCODE_PROJ"
    exit 1
fi
echo "   Project found."

# Check 3: Team ID
echo ""
echo "🔐 Checking Team ID..."
TEAM_ID=$(grep -o 'DEVELOPMENT_TEAM = "[^"]*"' "$XCODE_PROJ/project.pbxproj" | head -1 | sed 's/.*"\(.*\)"/\1/')

if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "" ]; then
    echo "⚠️  DEVELOPMENT_TEAM is empty."
    echo ""
    echo "  YOU MUST SET YOUR TEAM ID BEFORE BUILDING:"
    echo "  ─────────────────────────────────────"
    echo "  1. Open GardenPlanner.xcodeproj in Xcode"
    echo "  2. Select the GardenPlanner target"
    echo "  3. Go to Signing & Capabilities"
    echo "  4. Check 'Automatically manage signing'"
    echo "  5. Select your team from the dropdown"
    echo "  6. Save (⌘S)"
    echo "  7. Run this script again"
    echo ""
    echo "  To find your Team ID:"
    echo "  - Apple Developer Portal: https://developer.apple.com/account"
    echo "  - Or: Xcode → Preferences → Accounts → select your account"
    echo "  ─────────────────────────────────────"
    exit 1
fi

echo "   Team ID: $TEAM_ID"

# Check 4: Provisioning profiles (optional — Xcode can generate)
echo ""
echo "📜 Checking provisioning profiles..."
PROFILE_PATH=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | head -1)
if [ -n "$PROFILE_PATH" ]; then
    echo "   Provisioning profiles found."
else
    echo "   No provisioning profiles found (Xcode will generate one)."
fi

# Check 5: Output directory
echo ""
mkdir -p "$OUTPUT_DIR"
echo "📦 Output directory: $OUTPUT_DIR"

# Build!
echo ""
echo "🔨 Building Release archive..."
echo "================================================================"

xcodebuild archive \
    -project "$XCODE_PROJ" \
    -scheme GardenPlanner \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$OUTPUT_DIR/GardenPlanner.xcarchive" \
    -allowProvisioningUpdates \
    ASSETCATALOG_COMPILER_INCLUDE_SDCC=NO \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    2>&1 | tee "$OUTPUT_DIR/build.log"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed. Check $OUTPUT_DIR/build.log for details."
    echo ""
    echo "Common issues:"
    echo "  - Team ID doesn't match your Apple Developer account"
    echo "  - Distribution certificate is expired"
    echo "  - Bundle ID doesn't match App Store Connect"
    exit 1
fi

echo ""
echo "✅ Archive created. Exporting IPA..."
echo "================================================================"

# Export the IPA
xcodebuild -exportArchive \
    -archivePath "$OUTPUT_DIR/GardenPlanner.xcarchive" \
    -exportPath "$OUTPUT_DIR" \
    -exportOptionsPlist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>compileBitcode</key>
    <false/>
    <key>embedWithoutCompatibleBitcode</key>
    <false/>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
PLIST

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ IPA export failed. Check build log."
    exit 1
fi

# Find the IPA
IPA_PATH="$OUTPUT_DIR/GardenPlanner.ipa"
if [ -f "$IPA_PATH" ]; then
    IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
    echo ""
    echo "================================================================"
    echo "  ✅ BUILD COMPLETE!"
    echo "================================================================"
    echo ""
    echo "  IPA location: $IPA_PATH"
    echo "  IPA size:     $IPA_SIZE"
    echo ""
    echo "  To upload to TestFlight:"
    echo "  ─────────────────────────────────────"
    echo "  1. Go to https://appstoreconnect.apple.com"
    echo "  2. My Apps → 3D Garden Planner → TestFlight"
    echo "  3. Click the + (plus) in the Builds section"
    echo "  4. Drag and drop $IPA_PATH"
    echo ""
    echo "  Or use Apple's Transporter app:"
    echo "  https://apps.apple.com/us/app/transporter/id1450874784"
    echo "  ─────────────────────────────────────"
else
    echo "❌ IPA not found after export. Check build.log."
    exit 1
fi

echo "================================================================"
