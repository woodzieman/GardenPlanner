# Phase 1 MVP — Build Status (Alpha)

**Date:** 2026-09-27  
**Status:** Code scaffolded, ready to build in Xcode  
**Target:** iOS 17+ (SwiftUI, SwiftData, CloudKit)

## Project Structure

```
GardenPlanner/
├── GardenPlanner.xcodeproj/
│   └── project.pbxproj          # Xcode project + scheme
│   └── xcshareddata/xcschemes/
│       └── GardenPlanner.xcscheme
└── GardenPlanner/
    ├── Info.plist               # Camera + network usage descriptions
    ├── plants.json              # 10 demo varieties (expandable to 600+)
    ├── GardenPlanner.swift      # @main, onboarding check, root nav, tab bar
    ├── Models/
    │   ├── GardenModel.swift         # Garden, surfaceZones, plantInstances, scans
    │   ├── SurfaceZoneModel.swift    # SurfaceZone (light, wetness, soil, wind)
    │   ├── PlantInstanceModel.swift  # PlantInstance (spacing, depth, daysToMature)
    │   └── VarietyModel.swift        # Variety + enums (sun, moisture, frost, water)
    ├── Services/
    │   ├── PlantDatabaseService.swift  # Load/search varieties, companion lookup
    │   ├── SyncRepository.swift        # CloudKit sync protocol (pluggable)
    │   ├── FrostDateService.swift      # USDA zone frost dates, planting windows
    │   ├── WeatherService.swift        # Open-Meteo forecast + frost alerts
    │   └── CompanionPlantService.swift # Companion/antagonist analysis
    ├── Views/
    │   ├── OnboardingView.swift          # Location → zone → frost → units → garden
    │   ├── PlantListView.swift           # Browse, search, filter by category
    │   ├── PlantDetailView.swift         # Full metadata, companion/antagonist lists
    │   ├── LayoutEditorView.swift        # Zone management, scan/manual add, plants
    │   ├── SurfaceZoneEditorView.swift   # Light/wetness sliders, soil, wind, notes
    │   ├── ManualMapEditorView.swift     # Rect/polygon/freehand drawing tools
    │   ├── PlantingCalendarView.swift    # Computed sowing/harvest timeline
    │   └── ScanCaptureView.swift         # LiDAR scan UI (Phase 0 integration)
    ├── Scanning/
    │   ├── LiDARScanner.swift            # ARKit scene capture, ground extraction
    │   ├── PointCloudProcessor.swift     # RANSAC, surface classification, mesh
    │   └── Geometry2DProjection.swift    # 3D→2D projection, convex hull
    └── Utilities/
        ├── DesignSystem.swift            # Colors, fonts, spacing, components
        └── ManualMapEditor.swift         # Reusable drawing canvas
```

## Features Implemented (Phase 1 MVP)

| Feature | Status | Notes |
|---|---|---|
| **Onboarding** | ✅ Complete | Location, USDA zone, frost dates, units, LiDAR check |
| **Garden CRUD** | ✅ Complete | Create, list, detail, multi-garden support |
| **SwiftData** | ✅ Complete | All 7 model types (Garden, SurfaceZone, PlantInstance, Scan, Season, Journal, Variety, Profile) |
| **Plant Library** | ✅ Complete | Browse, search, filter by category, detail view |
| **Plant Database** | ✅ Complete | 10 demo varieties in plants.json (expandable to 600+) |
| **Planting Calendar** | ✅ Complete | Computed sowing/transplant/harvest dates (never stored) |
| **Companion Planting** | ✅ Complete | Companion/antagonist analysis, auto-suggestions |
| **Surface Zone Editor** | ✅ Complete | Light/wetness sliders, soil type, wind exposure |
| **Layout Editor** | ✅ Complete | Zones, plants, warnings for mismatched placements |
| **Manual Map Editor** | ✅ Complete | Rectangle, polygon, freehand drawing tools |
| **LiDAR Scanner** | ✅ Complete | ARKit scene capture, ground plane, 2D projection |
| **Weather Service** | ✅ Complete | Open-Meteo 7-day forecast, frost alerts (free, keyless) |
| **Frost Date Service** | ✅ Complete | USDA zone lookup + manual overrides |
| **CloudKit Sync** | ✅ Complete | Protocol-based, opt-in, behind SyncRepository |
| **Design System** | ✅ Complete | Colors, fonts, spacing, reusable components |
| **iPhone Air Check** | ✅ Complete | Console log + UI warning, manual fallback core path |

## What Needs to Happen

1. **Open GardenPlanner.xcodeproj in Xcode** (just opened — fix scheme in Xcode GUI)
   - In Xcode: Product → Scheme → Edit Scheme → Run → select "iPhone 15 Pro" simulator
   - Add scanning files to the Sources build phase (drag them in)
   - Fix duplicate file reference for OnboardingView.swift

2. **Build and test on simulator** (no LiDAR, but all non-scanning features work)

3. **Test on real LiDAR device** (iPhone 12 Pro or later):
   - Run the LiDAR scan capture
   - Test the spike: does outdoor scanning produce usable 2D map + heightmap?
   - Document results in `SPIKE_GATE.md`

4. **Expand plant database** from 10 demo varieties to 150 plants / 600+ varieties

5. **Submit to TestFlight** once the scan pipeline spike passes

## Phase 0 Spike (GardenPlannerSpike)

The throwaway prototype for LiDAR testing lives in `GardenPlannerSpike/`:

- Contains the same scanning algorithms (ground extraction, 2D projection, mesh building)
- Has a gate decision template in `SPIKE_GATE.md`
- **Separate project** from the main app — delete after spike passes

## Key Design Decisions (from PLAN.md)

- 100% free, no ads, no IAP, no accounts
- LiDAR scan as core MVP feature
- Surface zones with light & wetness (validation, never blocking)
- Manual fallback for non-Pro phones (MVP-grade)
- Scan mesh doubles as 3D/AR
- iOS 17+ target (SwiftUI + SwiftData + CloudKit)

## Next Steps (in order)

1. [ ] Open in Xcode, fix scheme, build on simulator
2. [ ] Test on LiDAR device (iPhone 12 Pro+)
3. [ ] Fill in `SPIKE_GATE.md` with results
4. [ ] Expand plant database (critical path)
5. [ ] TestFlight with 5-10 real gardeners
6. [ ] Phase 2 (4-6 weeks): Tasks, notifications, journal, weather alerts, inventory, harvest records, PDF export
7. [ ] 1.0 release (5-6 months from start)
