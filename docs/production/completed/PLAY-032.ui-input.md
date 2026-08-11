# PLAY-032 — Direct warning remedy

- Candidate branch: `codex/citysim-ui-play032-currentcc81`
- Base: `cc8145bee3b2d1be6c328bca5f44b2c56596ccea`
- Outcome: the latest `Severe Storm` warning keeps its authoritative cause and consequence visible and exposes the existing `Review utilities` response directly in the Strategy HUD.
- Intent parity: the pointer/keyboard/Full Keyboard Access/VoiceOver button uses the existing `CityNoticeActionCatalog` response and `CityGameStore` intent; the route opens the existing utilities inspector without changing selection, map focus, Escape, undo, or text-entry handling.
- Bounds: focused bitmap proof passed at compact `884 × 48` and regular `1240 × 52`; proof images were exported to `/private/tmp/CITYSIM-PLAY032-after-compact.png` and `/private/tmp/CITYSIM-PLAY032-after-regular.png`.
- Focused command: `swift test --disable-sandbox --package-path Native/CitySimNative --scratch-path /private/tmp/PLAY-032-currentcc81-scratch --filter PLAY032DirectRemedyTests` with isolated SwiftPM caches; final rerun passed 2 tests.
- Boundary: focused candidate evidence only; no aggregate suite, staged app, launch, push, integration, or release claim.
