#!/bin/bash
# =============================================================================
# Certificate & Provisioning Profile Setup for GardenPlanner TestFlight
# =============================================================================

set -e

APP_BUNDLE_ID="com.josephwoods.GardenPlanner"
XCODE_PROJ="../GardenPlanner/GardenPlanner.xcodeproj"

echo "================================================================"
echo "  GardenPlanner TestFlight Setup Checker"
echo "================================================================"
echo ""

# Check 1: Xcode command line tools
echo "Checking Xcode command line tools..."
if xcode-select -p > /dev/null 2>&1; then
    XCODE_PATH=$(xcode-select -p)
    echo "  Xcode found at: $XCODE_PATH"
else
    echo "  ERROR: Xcode not found."
    exit 1
fi

# Check 2: Project exists
echo ""
echo "Checking project..."
if [ -f "$XCODE_PROJ/project.pbxproj" ]; then
    echo "  Project found"
else
    echo "  ERROR: Project not found at $XCODE_PROJ"
    exit 1
fi

# Check 3: Bundle ID
echo ""
echo "Checking bundle ID..."
BUNDLE_ID=$(grep -oP 'PRODUCT_BUNDLE_IDENTIFIER = \K[^;]+' "$XCODE_PROJ/project.pbxproj" | head -1)
if [ -n "$BUNDLE_ID" ]; then
    echo "  Bundle ID: $BUNDLE_ID"
fi

# Check 4: Team ID
echo ""
echo "Checking development team..."
TEAM_ID=$(grep -oP 'DEVELOPMENT_TEAM = "\K[^"]+' "$XCODE_PROJ/project.pbxproj" | head -1)
if [ -n "$TEAM_ID" ] && [ "$TEAM_ID" != "TEAM_ID_PLACEHOLDER" ]; then
    echo "  Team ID: $TEAM_ID"
    echo "  Team ID configured successfully!"
else
    echo "  WARNING: DEVELOPMENT_TEAM is set to 'TEAM_ID_PLACEHOLDER'"
    echo ""
    echo "  HOW TO SET YOUR TEAM ID:"
    echo "  -----------------------------------------------"
    echo "  1. Open GardenPlanner.xcodeproj in Xcode"
    echo "  2. Select the GardenPlanner target"
    echo "  3. Go to Signing & Capabilities"
    echo "  4. Check Automatically manage signing"
    echo "  5. Select your team from the dropdown"
    echo "  6. Xcode will set the correct DEVELOPMENT_TEAM"
    echo ""
    echo "  TO FIND YOUR TEAM ID:"
    echo "  1. Go to https://developer.apple.com/account"
    echo "  2. Your Team ID appears in the upper right"
    echo "  3. Or Xcode -> Preferences -> Accounts -> select account"
    echo "     -> Team ID shown next to your name"
    echo "  -----------------------------------------------"
fi

# Check 5: Provisioning profiles
echo ""
echo "Checking provisioning profiles..."
PROFILE_COUNT=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PROFILE_COUNT" -gt 0 ]; then
    echo "  Found $PROFILE_COUNT provisioning profile(s)"
else
    echo "  No provisioning profiles found (Xcode auto-generates these)"
fi

# Check 6: API key
echo ""
echo "Checking API key..."
if [ -f "fastlane/app_store_connect_api_key.json" ]; then
    if grep -q "YOUR_KEY_ID_HERE" "fastlane/app_store_connect_api_key.json"; then
        echo "  API key needs to be configured (placeholder values)"
    else
        echo "  API key appears configured"
    fi
else
    echo "  No API key file (optional for manual export)"
fi

echo ""
echo "================================================================"
echo "  READY TO BUILD?"
echo "================================================================"
if [ -n "$TEAM_ID" ] && [ "$TEAM_ID" != "TEAM_ID_PLACEHOLDER" ]; then
    echo "  YES! Run: cd fastlane && bundle exec fastlane export_ipa"
else
    echo "  NO - Set your Team ID first (see instructions above)"
fi
echo "================================================================"
