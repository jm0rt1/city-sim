# PLAY-101 Claim — candidate-neutral authored-view intake

- **Title:** Prepare the exact authored-view intake/quarantine graph without shipping assets
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/3db4/city-sim`
- **Authority baseline:** The current Integration master commit containing this claim
- **Owning thread:** `019fe8f2-43ac-7700-9eaf-e173f43a569c`
- **Owned roots:**
  `Native/CitySimNative/Tests/CitySimNativeTests/SingleAngleWorldArtTests.swift`
  and `docs/production/evidence/PLAY-101/v2/`
- **Bounded deliverable:** Extend candidate-neutral validation/evidence for the
  43 identity × 4 authored-view × 3 LOD matrix, stable identity/variant keys,
  frontage mapping, alias/transform rejection, quarantine invariants, and
  deterministic handoff shape. This packet may prepare tests and evidence only;
  it must not ingest source, modify renderer selectors, or activate resources.
- **Dependencies:** The current PLAY-106 aggregate validator/report, current
  South status, CONTRACT-025/026/027/028, and exact family evidence. South is
  still 0/43 admitted, so the packet is explicitly synthetic/candidate-neutral.
- **Focused proof:** Static schema/inventory checks, deterministic fixture replay,
  focused world-art tests, and `git diff --check`.
- **Independent/full gate:** Integration owns the full Swift/resource gate after
  exact aggregate admission; independent Frontier owns visual/runtime acceptance.
- **Stop/refill:** Stop on any source/admission/resource/runtime path request,
  identity/variant ambiguity, alias/fallback/rotation substitution, or missing
  aggregate input. Refill only with another evidence-only renderer fixture.
- **Forbidden:** `Native/CitySimNative/Sources`, shipping resources/atlases,
  runtime selector code, world-art source roots, South admission, app launch,
  production selection, push, integration, and self-acceptance.
- **Status:** Fresh current-master candidate-neutral claim; no source or runtime
  readiness is implied.
