# PLAY-032 — Direct warning remedy

- Candidate branch: `codex/citysim-ui-play032-currentcc81`
- Base: `cc8145bee3b2d1be6c328bca5f44b2c56596ccea`
- Outcome: the latest `Severe Storm` warning keeps its authoritative cause and consequence visible and exposes the existing `Review utilities` response directly in the Strategy HUD.
- Intent parity: the pointer/keyboard/Full Keyboard Access/VoiceOver button uses the existing `CityNoticeActionCatalog` response and `CityGameStore` intent; the route opens the existing utilities inspector without changing selection, map focus, Escape, undo, or text-entry handling.
- Bounds: focused bitmap proof passed at compact `884 × 48` and regular `1240 × 52`; proof images were exported to `/private/tmp/CITYSIM-PLAY032-after-compact.png` and `/private/tmp/CITYSIM-PLAY032-after-regular.png`.
- Focused command: `swift test --disable-sandbox --package-path Native/CitySimNative --scratch-path /private/tmp/PLAY-032-currentcc81-scratch --filter PLAY032DirectRemedyTests` with isolated SwiftPM caches; final rerun passed 2 tests.
- Integrated candidate: `d8d2fa799cb5d07d611773fa49418b5a755127da` (tree `f25e7ea5ac144b56fbbcf74de62df04fb70a97b7`).
- Integrated gate: aggregate PASS, 369 executed / 2 skipped / 0 failures; isolated stage-only build PASS.
- Independent real-app result: `APPROVE_PLAY032_DIRECT_REMEDY`; pointer and keyboard/FKA reached the same Utilities remedy, truthful AX semantics and stable state passed, Escape closed cleanly, and the exact 900×600 presentation remained usable.
- Durable QA receipt: `docs/production/evidence/PLAY-032/currentcc81/QA-PASS.json`, SHA-256 `34ac2e469e83664b8cc1a540f6582f4911da8c4d3d841d6710c7033de3276d59`.
- Boundary: accepted player outcome only; no push, release, or public-release claim.
