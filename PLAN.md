# Garden Planner App — Market Research & Build Plan (v2)

An iPhone/iPad garden planning app. v2 incorporates the confirmed product decisions:

1. **100% free, no ads, no paywall, no account required** (private sync optional).
2. **LiDAR scanning (iPhone Pro / iPad Pro)** captures your actual yard layout.
3. **Editable surfaces/zones** — concrete, foot paths, garden beds, lawn, containers — each with **user-adjustable light and wetness**, which then validate and guide plant placement.

Market context (from v1 research, still valid): the category core is a drag-drop layout editor, a detailed plant database, a frost-date-driven planting calendar, companion-planting feedback, tasks, journal, weather, and harvest records ([Smart Gardener](https://www.smartgardener.com/), [Seedtime](https://seedtime.us/), [Planter](https://planter.garden/), GrowVeg, Veggie Garden Planter). The 2025–26 trend is 3D/AR/AI visualization (Planner 5D, GardenBox 3D, iScape, Scapes).

**Our wedge:** competitors plan an *abstract grid of beds*. We plan your *actual yard* — scanned with LiDAR, surfaced with real ground types, and lit/watered the way it really is. "Is this spot full-sun and dry?" is a question no current planner can answer.

---

## Part 1 — Feature set

### 1. Yard capture (the differentiator)

| Feature | Detail |
|---|---|
| **LiDAR scan** | ARKit LiDAR capture session (RealityKit capture API, iOS 17+) while the user walks the garden. On-device post-processing: ground/top-surface extraction, mesh decimation, orthographic 2D projection + heightmap. |
| **Surface zones** | User paints/lasso zones onto the map and assigns a surface type: **garden bed, raised bed/container, concrete/patio, foot path, lawn, water feature, other**. Edges editable per zone; heights/levels retained from the scan (a path a step below the lawn shows). |
| **Per-zone environment** | User-adjustable sliders: **light** (shade → full sun, or % sun) and **wetness** (dry → saturated; drainage). Optional add-on inputs: soil type, wind exposure. |
| **Smart hints (assist, not control)** | Heightmap/geometry cues (steps, edges, flat hard surfaces) pre-label candidate zones; user confirms. A sun model (location + time of day + terrain height) can *suggest* light values the user adjusts. User always has final say. |
| **Rescan & history** | Scans are versioned per season; diff view of how the yard changed; last year's zones pre-loaded. |
| **Non-LiDAR fallback** | Manual map editor (rect/curve/freehand with real-world dimensions), or photo-based tracing of a top-down picture with scale calibration. Standard iPhones (no LiDAR) get a full-featured app; LiDAR devices get the magic path. |
| **3D & AR (free with the scan)** | The captured mesh doubles as a 3D walkthrough (walk through your garden) and an AR true-scale preview ("will this tomato cage fit here?"). No separate modeling work needed — the scan *is* the 3D model. |

### 2. Planning core (category standard)

- **Layout editor** — beds, containers, in-ground rows; square-foot grid (auto per-square counts), row spacing, custom spacing, free-form; drag/drop, snap, undo, pinch-zoom; phone-first touch UX (competitors' #1 weakness).
- **Plant database** — start with ~150 plants / 600+ varieties: spacing, depth, days to maturity, **sun requirement, moisture requirement**, frost tolerance, water, harvest window, companions/antagonists, SFG per-square counts. Shipped in-app (JSON), user-definable custom plants.
- **Plant placement validation** — plants can only go on plantable surfaces; a full-sun crop in a shade zone or a dry-lover in a saturated zone gets a warning; "suggestions" mode highlights compatible zones for a chosen crop. *This is where light/wetness data becomes a feature, not just metadata.*
- **Planting calendar** — seed-start / transplant / harden-off / harvest bars per crop, computed from zone + frost dates (USDA zones, NWS/frost APIs, manual overrides); dragging a planting shifts its date chain; succession windows visible.
- **Companion planting** — live good/bad-neighbor feedback while arranging; one-tap auto-arrange.
- **Tasks** — weekly "do this now" list from the calendar + push notifications.
- **Journal** — per-plant/zone notes, photos, dated; season archive.
- **Weather** — local forecast + frost-approaching and planting-window alerts (Open-Meteo, free, no key).
- **Inventory & harvest records** — seed box; yield logs with season-over-season analytics.
- **Export/share** — labeled top-down map (surfaces + plants + legend) as PDF/image; shareable.

### 3. Explicitly *not* doing

- No ads, no subscriptions, no IAP, no accounts. Free forever.
- No paid server-side AI (costs can't be passed on). If AI helps, it's **on-device** only (e.g., plant ID via on-device vision model — Phase 3, optional).
- No web app, no Android. (Keep scope honest for a free app.)

---

## Part 2 — Build plan

### Tech stack

| Layer | Choice | Why |
|---|---|---|
| UI | **SwiftUI** (iOS 17+) | One codebase, iPhone + iPad; canvas via `Canvas`/`ScrollView`/gesture system |
| Scan | **ARKit + RealityKit capture session** (LiDAR), on-device mesh processing (decimate, ground extraction, 2D projection) | Native LiDAR; keeps everything private and offline |
| 3D/AR views | RealityKit / SceneKit rendering of the captured mesh | The scan doubles as the 3D/AR model |
| Persistence | **SwiftData**, local-first | Offline is a hard requirement (people are in the garden) |
| Sync | **CloudKit private DB** (optional, no public account) — behind a repository protocol so it can be dropped | Free, private, no backend to operate for a free app |
| Frost/zone | USDA PHZ API + NWS frost lookup, manual override | Free |
| Weather | Open-Meteo (free, keyless) | Fits a free app's cost model |
| Plant data | Curated in-app JSON DB (USDA/extension/seed-catalog sourced), versioned | Content = the moat; works offline |

### Data model (core)

```
Garden
 ├── < SurfaceZone      (name, surfaceType: bed|raisedBed|container|concrete|
 │ │                     path|lawn|water|other, polygon, elevation,
 │ │                     light: 0–100%/sunClass, wetness: dry–saturated, soil?, wind?)
 │ │   └── < PlantInstance (variety FK, position, qty, planted date, status)
 ├── < Scan             (mesh ref, heightmap ref, captured date, version) — rescan history
 ├── < Season           (2026, 2027: zones + plantings + calendar per season)
 ├── < JournalEntry     (date, note, photos, linked zones/plants)
 ├── < Task             (derived from calendar or manual, due, done)
 ├── < HarvestRecord    (plant, qty, date)
 ├── < InventoryItem    (seed/supply, qty)
 └── Profile            (location, zone, frost dates, household size, units, LiDAR device)

Variety (name, family, category, spacing, depth, daysToMature,
         sunReq, moistureReq, frostTolerance, waterNeed, sowStart,
         transplant, harvestWindow, companions[], antagonists[], sfgPerSquare)
```

Calendar dates are **computed, never stored**: profile + variety → dates.

### Phased roadmap

| Phase | Contents | Est. |
|---|---|---|
| **0 — Foundations** | App skeleton; onboarding (location → zone → frost dates → units → LiDAR capability check); SwiftData + CloudKit sync; design system; **plant DB content project starts immediately** (critical path) | 2–3 wks |
| **1 — Scan & Plan (MVP)** | LiDAR capture → post-processed map + heightmesh; zone painting (surface type, light, wetness, soil); zone editing (bounds, merge, delete); 3D walkthrough + AR preview of the scan; layout editor with placement validation; plant library + details; planting calendar; companion feedback; manual map fallback for non-LiDAR phones | 8–10 wks |
| **TestFlight** | Usability with 5–10 real gardeners (include 3+ non-Pro iPhone owners to validate the fallback) | 2 wks |
| **2 — Track the season** | Tasks + notifications; journal + photos; weather & frost alerts; inventory; harvest records + analytics; PDF/image export | 4–6 wks |
| **3 — Deepen** | On-device plant ID ("what is this?" → add to bed); plan-block library (free, curated succession plans); season rescan diffs; multi-garden; sharing a map with a partner | ongoing |

**Release shape:** TestFlight = Phase 1. **1.0 = Phases 1+2** (the full scan → plan → grow → track loop). 1.x/2.0 = Phase 3.

### Monetization

None. Free, no ads, no IAP. Consequence: every dependency must be free or keyless (hence Open-Meteo, USDA/NWS APIs, CloudKit, on-device ML only), and there is no budget for server AI. This is a portfolio/passion economics decision — scope discipline is the real budget.

### Risks & mitigations

| Risk | Mitigation |
|---|---|
| LiDAR only on Pro devices (iPhone 11 Pro–16 Pro, iPhone Air, iPad Pro) | First-class manual/photo fallback map editor in the MVP, not an afterthought |
| Outdoor LiDAR scanning is hard (shadows, moving people/pets, open sky) | Capture UX with guidance (walk speed, coverage meter); conservative ground extraction; user can always fix the resulting map by hand — the scan seeds the editor, it doesn't gate it |
| Mesh post-processing is the riskiest technical item (ground extraction, decimation, 2D projection) | Spike it in Phase 0 week 1 with a throwaway prototype before committing; worst case ship 3D/AR in Phase 2 while the 2D map stays core |
| Plant data accuracy (trust = everything here) | Curate from USDA/extension/seed-catalog sources; version the DB; manual date overrides; "verify locally" framing |
| Light/wetness inputs could feel like busywork | Keep them to two 3-stop sliders with sensible auto-hints; never require them to place a plant — warnings only |
| Free forever → zero revenue to fund scope creep | Hard phase gates; cut Phase 3 items freely if Phases 1–2 slip |

### Solo-dev effort

~3 months to TestFlight, ~5–6 months to 1.0 with this stack, assuming the scan-pipeline spike succeeds early. Plant content curation runs in parallel from week 1 and is the most likely critical path.
