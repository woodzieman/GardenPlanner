# App Store Connect – Alpha Build Checklist

**Project:** Garden Planner App
**Xcode project:** GardenPlanner/GardenPlanner.xcodeproj
**Bundle ID:** com.josephwoods.GardenPlanner
**Current display name in Info.plist:** 3D Garden Planner
**iOS deployment target:** 17.0
**SKU suggestion:** GARDEN-PLANNER-ALPHA-001

## 1. Xcode – Prepare Alpha Build

1. Open `/Users/josephwoods/Documents/Garden planner app/GardenPlanner/GardenPlanner.xcodeproj` in Xcode.
2. Select the GardenPlanner target → Signing & Capabilities
   * Choose your Apple Developer Team.
   * Enable Automatic signing. Xcode will create a provisioning profile for the bundle ID `com.josephwoods.GardenPlanner`.
   * Verify the bundle ID matches App Store Connect record.
3. Set scheme:
   * Product → Scheme → Edit Scheme → Run → Build Configuration = Debug
   * Destination = iPhone 15 Pro simulator for first build.
4. Fix project issues noted in PHASE1_STATUS.md:
   * Ensure all Scanning files are in the target’s Compile Sources.
   * Resolve duplicate file reference for OnboardingView.swift if Xcode warns.
5. Build:
   * Cmd+R to build on simulator. Confirm no errors.
   * Test non-LiDAR flows: Onboarding → Plant Library → Layout Editor → Manual Map Editor → Planting Calendar.
6. Archive for TestFlight:
   * Product → Archive → select Generic iOS Device.
   * In Organizer, Distribute App → App Store Connect → upload.
   * Set version = 1.0, build number = 1.

## 2. App Store Connect – Create App Record

1. Go to https://appstoreconnect.apple.com
2. Apps → + → New App
3. Fill dialog:
   * **Platform:** iOS
   * **Name:** 3D Garden Planner (or Garden Planner – LiDAR)
   * **Primary language:** English
   * **Bundle ID:** com.josephwoods.GardenPlanner
   * **SKU:** GARDEN-PLANNER-ALPHA-001
   * **User Access:** Full Access
4. Create.
5. App Information:
   * App Name: 3D Garden Planner
   * Subtitle: LiDAR garden planning
   * Category: Lifestyle / Utilities
   * Content Rights: No
6. Pricing and Availability: Free, all territories.
7. App Privacy: Fill questionnaire – no account, no tracking, on-device data only.
8. TestFlight:
   * Add internal testers or create external TestFlight group.
   * Upload build from Xcode; assign to TestFlight group.
   * Add Beta App Review information: “Alpha build for internal gardeners, no production data.”

## 3. Metadata for Alpha

* **App Store Name:** 3D Garden Planner
* **Description draft:** Plan your actual yard with LiDAR scanning, surface zones with light/wetness, plant library, planting calendar, companion planting. 100% free, on-device.
* **Keywords:** garden planner, LiDAR, planting calendar, companion planting
* **Support URL:** placeholder
* **Marketing URL:** placeholder

## 4. Next Gates

* [ ] Xcode build succeeds on simulator
* [ ] Archive uploads to App Store Connect
* [ ] App record created with bundle ID com.josephwoods.GardenPlanner
* [ ] TestFlight internal group created
* [ ] Phase 0 LiDAR spike validated and SPIKE_GATE.md filled
* [ ] Plant DB expanded from 10 demo varieties to production set

Notes:
* App is free, no ads, no IAP, no account. Keep privacy disclosures minimal.
* Camera usage description already in Info.plist for LiDAR scanning.
