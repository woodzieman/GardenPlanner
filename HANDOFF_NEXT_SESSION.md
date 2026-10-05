# Handoff — Garden Planner App (Current State)

**Date:** 2026-10-04  
**Status:** ✅ Main app + Spike both build green · Pushed to GitHub · Ready for TestFlight

---

## Where things stand

- **App builds clean** on Xcode 27.0 / iOS 27 SDK / Swift 6.4 (deployment target iOS 17.0, bundle `com.josephwoods.GardenPlanner`, team `VDWDUNC9R2`, version 2.0.0 (3)). Command-line `xcodebuild` → `** BUILD SUCCEEDED **`; remaining warnings are deprecation-only.
- **Repo:** https://github.com/woodzieman/GardenPlanner (public; make private if you prefer — no secrets in it: `.gitignore` excludes `*.p8` keys, `fastlane/app_store_connect_api_key.json`, fastlane output, xcuserdata, scratch).
- **Plant database (121 varieties) now actually loads** — two data/schema mismatches had been silently breaking the JSON decode and falling back to 8 demo plants. Both fixed and runtime-verified (see BETA_BUILD_STATUS.md).

## What the user needs to do (TestFlight)

1. Open `GardenPlanner/GardenPlanner.xcodeproj` in Xcode
2. Signing is already set to team `VDWDUNC9R2`; create a TestFlight distribution certificate/provisioning profile if Xcode asks (or use automatic signing)
3. Select a device destination (Any iOS Device) → Product → Archive → Distribute App → TestFlight
4. Bump MARKETING_VERSION/CURRENT_PROJECT_VERSION as needed (set in project settings; Info.plist is generated)

## Next work for agents (priority order)

1. **ScanCaptureView** is a placeholder UI (black box) — the LiDAR pipeline (`LiDARScanner.swift`, using iOS 27 `frame.sceneDepth`) is real; build a proper camera/preview UI
2. **Weather geocoding** is a small lookup table — add proper geocoding fallback
3. **PlantDetailView** — show barcode (`variety.barcode`)
4. **LayoutEditorView.isValid** is a placeholder — implement real light/moisture matching (GardenModel has a working `approximates`-based version to reuse)
5. **Spike project** is now fixed (see below) — run `GardenPlannerSpike/` on a LiDAR device, fill `SPIKE_GATE.md`

### Spike project — now buildable (fixed in this session)

The Spike project's obsolete ARKit API references (`supportedScenes`, `sceneReconstruction`, `hasIPhoneAir`, `SceneCapture`, `ARKitSession`) were replaced with iOS 27 API:
- `GardenPlannerSpike.swift`: `checkLiDARCapability()` → uses `ARWorldTrackingConfiguration.isSupported` + `supportsFrameSemantics([.sceneDepth])`
- `ScanCaptureView.swift` (CameraPreviewView): `sceneReconstruction = .mesh/.localMapped/.deviceDepth` → `frameSemantics = [.sceneDepth]`
- `ScanMapView.swift` (iOS 27 Canvas API fixes):
  - Canvas closure second param is `CGSize`, not `CGRect` — construct `CGRect` from `size`
  - `Path(rect:)` → create `Path()` then `addRect(rect)`
  - `addEllipse(at:width:height:)` → `addEllipse(in:)` with `CGRect`
  - `.color()` is a Canvas property, not a function — use `.color(color)`
  - All `Text` cases in `statusLabel` switch must have identical modifier chains (same font, no extra modifiers on one case)
- Spike Scanning files (`LiDARScanner.swift`, `PointCloudProcessor.swift`, `Geometry2DProjection.swift`) were already correctly replaced by the previous agent

## Critical iOS 27 API gotchas (verified against the iOS 27 SDK — do not regress)

- **iOS 27 SDK removed old ARKit depth APIs**: `ARFrame.depthData`, `isLiDARDepthInformationEnabled`, `supportedScenes`, `unprojectPosition`. Use `frame.sceneDepth` (CVPixelBuffer) + `camera.projectionMatrix` (property). Never use the removed ones.
- **Swift 6.4 SwiftData `@Model` macro rejects shorthand enum defaults** — write `= PlantStatus.planted`, not `= .planted`. Tuples are not persistable in `@Model`.
- `SpatialTapGesture.onEnded` hands you `Value` — read `.location` for the CGPoint.
- SwiftUI `Canvas { context, size in }` — the second parameter is **CGSize**, not CGRect.
- pbxproj: `objects` dict closes with `};`; subgroups use `path = X;` not `name = X;`. After adding/removing source files, run `python3 regenerate_pbxproj.py` (repo root).

## Reference

- [PLAN.md](PLAN.md) — product plan · [BETA_BUILD_STATUS.md](BETA_BUILD_STATUS.md) — full build log + feature checklist · [QUICK_START_TESTFLIGHT.md](QUICK_START_TESTFLIGHT.md) · [docs/](docs) — App Store Connect checklist
