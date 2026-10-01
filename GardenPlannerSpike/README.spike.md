# Phase 0 — LiDAR Capture Spike (Throwaway Prototype)

**Goal:** Answer the critical question — does outdoor LiDAR scanning → ground extraction → 2D map + heightmap produce something usable enough to build the MVP on?

**Status:** Scaffolded and ready to test.

## Project Structure

```
GardenPlannerSpike/
├── GardenPlannerSpike.xcodeproj/
│   └── project.pbxproj          # Xcode project (iOS 17+, SwiftUI)
└── GardenPlannerSpike/
    ├── GardenPlannerSpike.swift  # @main app entry, capability check
    ├── Info.plist                # Camera + local network usage descriptions
    ├── Scanning/
    │   ├── LiDARScanner.swift    # Core ARKit SceneCapture wrapper
    │   ├── PointCloudProcessor.swift  # Ground plane, surface classification, mesh building
    │   └── Geometry2DProjection.swift   # 3D→2D projection, convex hull, heightmap
    └── Views/
        ├── ScanCaptureView.swift      # Camera preview + capture button UI
        └── ScanMapView.swift          # 2D map + heightmap + surface zones display
```

## Quick Start

1. Open `GardenPlannerSpike.xcodeproj` in Xcode
2. Set deployment target to **iOS 17.0** (already configured)
3. Build and run on a **LiDAR device** (iPhone 12 Pro–16 Pro, iPad Pro M2+)
4. Tap **"Start Scan Capture"**, walk around a garden space for ~15 seconds
5. Tap **"Stop Scan"** and review the 2D map + heightmap output

## On Non-LiDAR Devices

The app detects missing LiDAR and shows a warning. The spike code will:
- Still run ARKit (using device depth from stereo cameras, if available)
- Still produce a 2D projection (just noisier)
- Report capability status to the console for the gate decision

## What the Spike Tests

| Question | How tested |
|---|---|
| Does outdoor LiDAR capture work in daylight? | AR session on actual garden |
| Can we extract a clean ground plane? | RANSAC in `PointCloudProcessor` |
| Can we get a recognizable 2D map? | `ScanMapView` displays the boundary |
| Does the heightmap show terrain variation? | Color-coded heightmap in UI |
| Can we classify surfaces (lawn, concrete, etc.)? | `classifySurface()` per region |
| iPhone Air — does it have LiDAR? | Console log + warning in UI |

## Gate Decision Criteria

**PASS** (proceed to Phase 1 MVP):
- Garden boundary is recognizable on the 2D map
- Heightmap shows meaningful variation (not all zeros)
- Surface classification produces at least 2 different zones
- The scan + processing completes in < 30 seconds

**FAIL** (pivot to manual editor as core path):
- Point cloud is too sparse/noisy to extract a ground plane
- 2D map is a single blob with no structure
- Heightmap is flat (no elevation data from capture)
- Outdoor conditions (shadows, moving objects) break the pipeline

## Key APIs Used

| API | Purpose |
|---|---|
| `ARKitSession` | Core AR session |
| `ARWorldTrackingConfiguration.sceneReconstruction = .mesh` | LiDAR mesh capture |
| `SceneCapture.loadScene(scene:)` | Load/extract captured scene data |
| `RealityKit.Mesh` | 3D surface geometry |
| `ARPointCloud` | Raw point cloud data per frame |

## Notes for the Pivot

If the spike fails, the MVP core path becomes the **manual map editor** (rect/curve/freehand with real-world dimensions). The LiDAR path (3D/AR) moves to Phase 2. See `PLAN.md` risk table.

## iPhone Air Check

The code checks for iPhone Air (single camera, no LiDAR):
- Console logs `"⚠ iPhone Air detected — single camera, no LiDAR"`
- UI shows a warning: `"LiDAR not detected"`
- This device **must** use the manual fallback path

If confirmed (no LiDAR on iPhone Air), the spike will document this and the manual editor becomes the MVP core.
