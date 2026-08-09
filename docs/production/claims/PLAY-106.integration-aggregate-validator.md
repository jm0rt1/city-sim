# PLAY-106 Claim

- **Title:** Bind the exact 43x4x3 aggregate candidate validator
- **Lane:** Integration-owned world-art admission mechanics
- **Branch:** `codex/citysim-play106-aggregate-validator`
- **Worktree:** `/private/tmp/citysim-play106-aggregate-validator`
- **Base authority:** `9997522bc863e8722e9e514beba02fe7e71ef7e7`
- **Exclusive roots:**
  `Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/aggregate/`
  and `docs/production/evidence/PLAY-106/aggregate-validator/`.
- **Dependencies:** CONTRACT-025, CONTRACT-026, CONTRACT-027, CONTRACT-028,
  and `docs/production/decisions/PLAY-106-RAW-SOUTH-ANCHOR-AUTHORITY.md`.
- **Deliverable:** Add a versioned, read-only schema and validator for an
  Integration-owned aggregate candidate manifest. It must require exactly 43
  logical identities, 172 authored direction rows, and 516 explicit LOD
  payloads; verify every referenced path and SHA-256, reject aliases,
  transforms, fallbacks, duplicate identities, unresolved duplicate raw files,
  missing directions, and readiness/admission/renderer/production assertions;
  and emit a deterministic machine-readable failure/pass report without
  changing source, art, or product state.
- **Status:** Active; implementation is mechanical and candidate-only. It does
  not admit pixels or authorize renderer, runtime, or production selection.

Focused proof must run in a fresh output root against the current 43x4 schema
and the preserved South/raw evidence, demonstrating deterministic output and a
truthful fail-closed result while the directional payloads are not complete.
The full Integration owner independently reviews the schema, path/hash audit,
duplicate handling, and false-flag boundary before any aggregate admission
packet can reference this validator.

No source generation, ImageGen, normalization, pixel repair, source admission,
canonical ledger/board/dispatch mutation, renderer/resource/runtime change,
app launch, production selection, push, or self-acceptance.
