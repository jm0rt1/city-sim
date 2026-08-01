# PLAY-084 model-routing pilot: UI focused gate

## Route identity

- Route: `pilot-v1:ui`
- Route SHA-256: `807f3b6a4b0ce9c9e28cf0ac6701e529afc14c7ddc98bdfe01362f7a346720b4`
- Dispatch receipt: `docs/production/evidence/INTEGRATION/MODEL-ROUTING-PILOT-DISPATCH-V1.json`
- Receipt carrier: `70c49f394a0920e26dffc945bd996cf67af7b1fe`
- Receipt file SHA-256: `79b5132e8144c5f0e81c592b746becffb7fe99aa97d3ac3b2a62bf997a24f42`
- Authority/base: `2753f42134fa85d8570849b57302cce0bc924566`
- Expected and actual starting HEAD: `087471fa90fd770161639f249e74b73925535193`
- Claim: `docs/production/claims/PLAY-084.ui-input.md` (SHA-256 `5ef636c7afe0e4ed5200f7e9e21b3b4bd1b0a8ca3b572de404e334565303b8f4`)

## Bounded validation

Focused owner gate, run against the unchanged expected-start tree:

```text
CLANG_MODULE_CACHE_PATH=/tmp/citysim-clang-cache \
SWIFT_MODULECACHE_PATH=/tmp/citysim-swift-cache \
swift test --package-path Native/CitySimNative --filter HUD
```

Result: **PASS**, 15 tests, 0 failures, 49.323 seconds.

The run covered `CityCommandCatalogTests` (4), `CitySimulationTests` HUD cases
(4), and `PLAY084HUDFeedbackTests` (7), including coalescing, current-value
primacy, recovery, measured aperture/non-clipping, Reduced Motion, and
keyboard-safe HUD selection. The measured layout output was:

```text
compact_top=104.0 compact_strategy=48.0 compact_bottom=58.0 compact_map=422.0
compact_top_inset=122.0 compact_bottom_inset=76.0
regular_top=118.0 regular_strategy=50.0 regular_bottom=60.0 regular_map=558.0
regular_top_inset=144.0 regular_bottom_inset=86.0
```

No claim-local defect was reproduced and no product source was changed. The
complete Swift suite, staged build, and independent real-app journey remain
Integration-owned gates and were not run in this focused packet.

`git diff --check` passes and the worktree is clean apart from this evidence
file before commit.
