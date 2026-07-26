# PLAY-074 Candidate Manifest

- **Branch:** `codex/citysim-ui-input`
- **Published authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Prior accepted UI evidence:** `67fa062`
- **Baseline-audit commit:** `deeca72f44d38921d23a5b67d5c6917b96cd4caf`
- **Product candidate:** `93693d0125f6cdd9ee660ea918891c23ed76bb4d`
- **Candidate ID:** `ui-input-wdbeadac6e0bd`
- **Bundle ID:** `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- **Staged app:** `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- **Executable:** `CitySimNative-wdbeadac6e0bd`
- **Executable SHA-256:**
  `243cbdf0c965724aa2b340866bbe930bf0435c3494d3726f6c1646552643fb4f`
- **Verified launch:** `2026-07-25T17:15:06Z`, PID `87740`
- **Retained staging manifest SHA-256:**
  `2e5e6f39d8dd5ea9982c93f5d2b3deb70e94cfd8551d74fe0f00475b05f837ce`

The exact verified process was stopped after the staged and live-app gates.
No matching candidate process remained at handoff.

## Bound journeys

Both journeys loaded isolated copies of the same accepted Day 11 quicksave:
the simulation was paused, treasury was `$31,078`, and no state was reset
between diagnosis and recovery.

| Layout | App frame | Exact content | Target | Binding frame SHA-256 |
| --- | --- | --- | --- | --- |
| Regular | 1278 x 768 | regular | occupied block 12,12 | `3a5c91dea1e5387e4ef0dea69b3712f867e210cd36ffd26fbe227e772beedbd5` |
| Compact | 900 x 652 | 900 x 600 plus 52-pixel titlebar | roadless block 14,16 | `10619a1e51fc7cc2b82cb9fbb920d753b20e755fc18ee5c5c602bb04c67e499a` |

The retained regular and compact frames are transient-free, candidate-bound,
and use `CITYSIM_REDUCE_MOTION_PROOF=1`. The baseline frames are retained
separately under `baseline-e38059e/`.
