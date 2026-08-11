# PLAY-106 Claim

- **Title:** Bind the exact 43-row South raw-authoring ledger and validator
- **Lane:** Integration-owned world-art admission mechanics
- **Owner:** Agent 007 — Agent Operations Lead
- **Thread:** `019fc40d-c697-7aa2-94bf-902b031a8c67`
- **Branch:** `codex/citysim-play106-agent007-currentc5`
- **Worktree:** `/private/tmp/citysim-play106-agent007-currentc5`
- **Base authority:** `c5a4ed66aa3fe655c9877a5070f34cf4d00cd5ab`
- **Exclusive roots:**
  `Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-096/aggregate/`
  and `docs/production/evidence/PLAY-106/aggregate-validator/`.
- **Dependencies:** CONTRACT-025, CONTRACT-026, CONTRACT-027, CONTRACT-028,
  and `docs/production/decisions/PLAY-106-RAW-SOUTH-ANCHOR-AUTHORITY.md`.
- **Deliverable:** Update the existing read-only aggregate validator and report
  so they publish exactly 43 canonical South raw-authoring rows and one
  deterministic canonical digest. Bind `industrial_l01_v0` only to
  `industrial_l01_v00-source-v01.png` SHA-256
  `7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2`.
  Preserve `industrial_l01_v00-source-v02.png` SHA-256
  `8e33dafb3a40f7dac6f5ca8c9c5cb81df2b63011d3fd0d4a0302ec04a99d264a`
  in a separate excluded-evidence collection with disposition
  `RETURN_source_v02_chroma_gate_failed`; it must not count as a logical
  identity, canonical row, source admission, direction, or retry. Add focused
  validator tests for row count, uniqueness, canonical digest determinism,
  v01 selection, v02 exclusion/preservation, hash tamper, duplicate canonical
  IDs, and false readiness/admission/renderer/production flags.
- **Status:** Active; implementation is mechanical and candidate-only. It does
  not admit pixels or authorize renderer, runtime, or production selection.

Focused proof must run the validator tests, generate a fresh report from the
current 43-row source inventory, prove byte identity with the committed report,
and pass `git diff --check`. The report remains authoring-reference authority
only while directional payloads are incomplete.
The full Integration owner independently reviews the schema, path/hash audit,
duplicate handling, and false-flag boundary before any aggregate admission
packet can reference this validator.

No source generation, ImageGen, normalization, pixel repair, source admission,
canonical ledger/board/dispatch mutation, renderer/resource/runtime change,
app launch, production selection, push, or self-acceptance.
