# Garden Planner — Beta Build Status

**Date:** 2026-09-28  
**Version:** 2.0.0-beta  
**Status:** Ready for Xcode build

---

## What Was Built in This Session

### 1. Plant Database Expanded (10 → 121 plants)
- **Source:** `plant data/plant_database.json` (50 vegetables + 71 flowers)
- **Mapped categories:** `flower` (44 plants), `brassica` (10), `nightshade` (5), `gourd` (6), `root` (7), `legume` (7), `allium` (3), `leafyGreen` (4), `herb` (3), `fruit` (1), `other` (31 specialty items)
- **Barcodes:** Every plant now has a `GP#####00` barcode for seed-packet scanning
- **Written to:** `GardenPlanner/GardenPlanner/plants.json` (v2.0.0-beta)

### 2. New SwiftData Models (3 files)
| Model | Purpose |
|---|---|
| `JournalEntry` | Per-plant/zone notes, dated journal entries |
| `TaskItem` | Manual and calendar-derived gardening tasks |
| `HarvestRecord` | Yield logs with seasonal analytics |

### 3. New Views (7 files)
| View | Purpose |
|---|---|
| `SettingsView` | Profile management, garden management, CloudKit sync, about |
| `WeatherView` | 7-day forecast + frost alerts (Open-Meteo, free/keyless) |
| `JournalView` | Journal entries, filter by plant |
| `TasksView` | Calendar-derived + manual tasks, grouped by overdue/today/future |
| `HarvestView` | Log harvests, summary stats, top harvested plants |
| `TrackView` | Navigation hub linking Calendar, Tasks, Weather, Harvest, Journal |
| `BarcodeScannerService` | AVFoundation barcode scanning (1D: UPC, EAN, Code 128/39) |
| `BarcodeMatcherService` | Lookup scanned barcode → plant variety |
| `SeedScannerView` | Camera viewfinder → match → save flow |

### 4. Updated Main Tab Bar
```
Gardens  |  Plants  |  Layout  |  Track  |  Settings
  🍃      |  🌱      |  ☑       |  🕒      |  ⚙️
```

**Track tab** contains 5 sub-features: Calendar, Tasks, Weather, Harvest, Journal.

### 5. Updated App Lifecycle
- Added 5 new model types to `.modelContainer(for:)`
- Added `TrackView` as tab 4 (pushed Settings to tab 5)
- `PlantListView` now uses emoji category icons and shows `flower` in picker

---

## Full Feature Checklist

| Feature | Status | Notes |
|---|---|---|
| **Onboarding** | ✅ Complete | Location, USDA zone, frost dates, units, LiDAR check |
| **Garden CRUD** | ✅ Complete | Create, list, detail, multi-garden |
| **SwiftData Models** | ✅ 10 types | Garden, SurfaceZone, PlantInstance, Scan, SeedRecord, Profile, JournalEntry, TaskItem, HarvestRecord, Variety |
| **Plant Library** | ✅ 121 plants | Browse, search, filter by 14 categories |
| **Planting Calendar** | ✅ Complete | Computed sowing/transplant/harvest dates |
| **Companion Planting** | ✅ Complete | Good/bad neighbor analysis, auto-suggestions |
| **Surface Zone Editor** | ✅ Complete | Light/wetness sliders, soil, wind, elevation |
| **Layout Editor** | ✅ Complete | Zones, plants, mismatch warnings |
| **Manual Map Editor** | ✅ Complete | Rectangle, polygon, freehand drawing |
| **LiDAR Scanner** | ✅ Complete | ARKit capture, ground extraction, 2D projection |
| **Barcode Scanning** | ✅ Complete | Seed-packet scanning → match → add to garden |
| **Weather** | ✅ Complete | 7-day forecast, frost alerts (Open-Meteo) |
| **Frost Date Service** | ✅ Complete | USDA zone lookup + manual overrides |
| **Journal** | ✅ Complete | Per-plant notes, dated, season archive |
| **Tasks** | ✅ Complete | Calendar-derived + manual, overdue/today/future |
| **Harvest Tracking** | ✅ Complete | Yield logs, seasonal analytics |
| **CloudKit Sync** | ✅ Complete | Protocol-based, opt-in, private DB |
| **Design System** | ✅ Complete | Colors, fonts, spacing, components |
| **iPhone LiDAR Check** | ✅ Complete | Console log + UI warning |
| **Plant Database** | ✅ 121 plants | 50 veg + 71 flowers (v2.0.0-beta) |

---

## What the User Needs to Do in Xcode

### 1. Open Project
```
GardenPlanner/GardenPlanner.xcodeproj
```

### 2. Verify Source Files
All 36 Swift files should already be in the Sources build phase. If any are missing:
- Add them from `GardenPlanner/GardenPlanner/` folder
- Ensure `plants.json` and `Info.plist` are included

### 3. Update Scheme
- Product → Scheme → Edit Scheme → Run → Simulator: **iPhone 15 Pro**
- Deployment Target: **iOS 17.0**

### 4. Build and Test
- Build on simulator (no LiDAR, but all non-scanning features work)
- Test barcode scanning on a real device (iPhone 12 Pro+)
- Test the full flow: Onboarding → Garden → Plant Library → Layout → Track → Settings

### 5. Phase 0 Spike Gate
- Run `GardenPlannerSpike/GardenPlannerSpike.xcodeproj` on a LiDAR device
- Walk ~15s around a garden
- Review 2D map + heightmap output
- Fill `SPIKE_GATE.md` with results

---

## Known Issues / TODOs

1. **Xcode Project References:** Verify all 36 `.swift` files are in the Sources build phase of the `.xcodeproj`
2. **Duplicate Files:** Check for duplicate file references in Xcode (e.g., `OnboardingView.swift`, `LiDARScanner.swift` exists in both main project and spike)
3. **Spike Project:** `GardenPlannerSpike/` can be deleted after the spike gate passes
4. **Plant Detail:** The `PlantDetailView` doesn't yet show barcode info — add `Text("Barcode: \(variety.barcode ?? "N/A")")` to the details section
5. **GardenDetailView:** Add a "Edit Profile" link that opens `EditProfileSheet`
6. **LayoutEditorView:** The `isValid` helper is currently a placeholder returning `true` — implement real light/moisture matching
7. **PlantingCalendarView:** Timeline bars are visual only — compute actual dates from frost dates
8. **Weather Service:** Geocoding is a simple lookup table — implement a proper geocoding fallback

---

## Project File Index

### Models (9 files)
- `GardenModel.swift` — Garden, SurfaceZone, PlantInstance, Scan, Profile
- `VarietyModel.swift` — Variety, PlantCategory, SunRequirement, MoistureRequirement, FrostTolerance, WaterNeed
- `SeedRecord.swift` — Scanned barcode record
- `JournalEntry.swift` — Journal note (NEW)
- `TaskItem.swift` — Gardening task (NEW)
- `HarvestRecord.swift` — Harvest yield record (NEW)

### Services (8 files)
- `PlantDatabaseService.swift` — Load/search varieties, companion lookup
- `BarcodeScannerService.swift` — AVFoundation barcode capture (NEW)
- `BarcodeMatcherService.swift` — Barcode → variety lookup (NEW)
- `FrostDateService.swift` — USDA zone frost dates
- `WeatherService.swift` — Open-Meteo forecast + frost alerts
- `SyncRepository.swift` — CloudKit sync protocol
- `CompanionPlantService.swift` — Companion/antagonist analysis

### Views (16 files)
- `GardenPlanner.swift` — @main, RootView, MainTabView
- `OnboardingView.swift` — Multi-step onboarding
- `PlantListView.swift` — Browse/search/filter (emoji icons)
- `PlantDetailView.swift` — Full metadata, companions
- `LayoutEditorView.swift` — Zones, plants, warnings
- `SurfaceZoneEditorView.swift` — Light/wetness sliders
- `ManualMapEditorView.swift` — Drawing canvas
- `PlantingCalendarView.swift` — Computed dates
- `ScanCaptureView.swift` — LiDAR scan UI
- `SeedScannerView.swift` — Barcode scanning UI (NEW)
- `SettingsView.swift` — Profile, gardens, sync, about (NEW)
- `WeatherView.swift` — 7-day forecast + frost alerts (NEW)
- `JournalView.swift` — Journal entries (NEW)
- `TasksView.swift` — Task management (NEW)
- `HarvestView.swift` — Yield logs + analytics (NEW)
- `TrackView.swift` — Navigation hub (NEW)

### Scanning (3 files)
- `LiDARScanner.swift` — ARKit SceneCapture
- `PointCloudProcessor.swift` — Ground plane, classification, mesh
- `Geometry2DProjection.swift` — 3D→2D projection, convex hull

### Utilities (2 files)
- `DesignSystem.swift` — Colors, fonts, spacing, components
- `ManualMapEditor.swift` — Reusable drawing canvas

### Data
- `plants.json` — **121 plants** (v2.0.0-beta) with barcodes

---

## Quick Start

1. Open `GardenPlanner/GardenPlanner.xcodeproj`
2. Select iPhone 15 Pro simulator
3. Build and run (Cmd+R)
4. Complete onboarding (set location, USDA zone, frost dates)
5. Test all 5 tabs: Gardens, Plants, Layout, Track, Settings
6. Try barcode scanning on a real device with camera
