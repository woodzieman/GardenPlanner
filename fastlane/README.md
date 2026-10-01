# Fastlane for Garden Planner Alpha

This folder automates building and TestFlight upload for the Garden Planner app.

## Prerequisites
- Ruby + Bundler
- Xcode 15+
- Apple Developer account
- App Store Connect API key

Install dependencies:
```bash
bundle install
```

## Usage

1. Create App Store Connect API key and save to `fastlane/app_store_connect_api_key.json`
2. Ensure app record exists in App Store Connect with bundle ID `com.josephwoods.GardenPlanner`
3. Run beta lane:
```bash
bundle exec fastlane beta
```

This will:
- Increment build number
- Build archive with `gym`
- Upload to TestFlight with `pilot`

## Files
- Fastfile – lanes
- Gymfile – build config
- APP_STORE_CONNECT_API_SETUP.md – API key setup
- app_store_connect_create_app_payload.json – example API payload for app creation
