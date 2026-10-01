# App Store Connect API Key Setup

To use fastlane pilot with App Store Connect API:

1. In App Store Connect: Users and Access → Keys → Generate API Key
   - Name: GardenPlanner CI
   - Access: App Manager
   - Download .p8 key

2. Save key as `fastlane/app_store_connect_api_key.json` with the following format:

{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
  "duration": 1200,
  "in_house": false
}

3. Set environment variables for CI:
   ASC_KEY_ID=...
   ASC_ISSUER_ID=...
   ASC_KEY_CONTENT=... # base64 encoded .p8

4. Run:
   bundle exec fastlane beta

Notes:
- First create the app record manually in App Store Connect with bundle ID com.josephwoods.GardenPlanner
- Ensure provisioning profile is valid for App Store distribution
- iOS deployment target is 17.0
