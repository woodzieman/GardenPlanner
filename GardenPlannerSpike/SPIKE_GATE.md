# Phase 0 Spike — Gate Decision Template

Run the spike, fill in the results, then decide: proceed to Phase 1 MVP or pivot?

## Test Run Results

### Device Info
| Field | Value |
|---|---|
| Device: | `# swift device info or manually enter` |
| iOS version: | `# version` |
| LiDAR present: | ☐ Yes  ☐ No  ☐ iPhone Air (no LiDAR) |
| Daylight conditions: | ☐ Overcast  ☐ Direct sun  ☐ Mixed shade |
| Scan duration: | `# seconds` |

### Output Quality

| Metric | Pass/Fail | Notes |
|---|---|---|
| Point cloud count | ☐ Pass (>10K pts)  ☐ Fail | `# number of points` |
| Ground plane extracted? | ☐ Pass  ☐ Fail | `# normal: (x, y, z), offset: val` |
| 2D map recognizable? | ☐ Pass  ☐ Fail | `# is the garden layout clear?` |
| Heightmap has variation? | ☐ Pass  ☐ Fail | `# min/max height: val / val` |
| Surface zones classified? | ☐ Pass  ☐ Fail | `# zones found: N` |
| Processing time < 30s? | ☐ Pass  ☐ Fail | `# seconds` |

### Observations

```
Notes from the test run:
- What worked well:
- What broke:
- Any surprises:
```

## Gate Decision

☐ **PASS** — Proceed to Phase 1 MVP (scan pipeline + zone painter)
  - The scan produces a usable map
  - Surface zones are identifiable
  - Heightmap shows real terrain data

☐ **CONDITIONAL PASS** — Proceed with caveats
  - Partial success; document what to fix
  - Manual editor will be the core path; LiDAR is a bonus

☐ **FAIL** — Pivot: manual map editor is the core path
  - LiDAR/3D/AR moves to Phase 2
  - MVP = Phase 1 (manual editor + plant DB + calendar)
  - Rescan pipeline deferred until Phase 2+

## iPhone Air Conclusion

☐ Confirmed: iPhone Air has LiDAR → include in scan path
☐ Confirmed: iPhone Air has NO LiDAR → must use manual fallback
☐ Undecided: Need to test on actual device

## Next Steps

- [ ] Fill in test results above
- [ ] Make gate decision (PASS / CONDITIONAL / FAIL)
- [ ] If FAIL, update `PLAN.md` roadmap to reflect pivot
- [ ] If PASS, begin Phase 1: Xcode scaffold + scan pipeline commit
