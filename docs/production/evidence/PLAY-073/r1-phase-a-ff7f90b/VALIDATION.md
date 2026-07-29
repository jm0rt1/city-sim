# PLAY-073 R1 Phase A renderer checkpoint

## Candidate identity

- Branch: `codex/citysim-world-rendering`
- Published authority merged without rewriting: `c9f250afbe3c4b4f3cebf044f5124c56f09b0bd9`
- Merge checkpoint: `bf95444bcc836cb2ad96a2c0111e15e7ad20bf7a`
- Exact PLAY-078 handoff adopted in order as local commits:
  - `a2e984a57db0cb83e00d3be515df32d0cea438e8`
  - `b6b7d72ee657bca42f2d674b186a9fbda3c5dae6`
  - `d2d2c2a1066af2269c5adb148f99929895541b40`
  - `3964213fcce773fa556d99137eb6c173d63dd39c`
  - `7dd3d5d6a2065e57e0f1fdaffbf199205d9cf76b`
  - `199b87663d38c78d236bf7fd49e01b071392720a`
- Renderer truth-adoption commit: `a61fd0c7d63e599d070a612468bbaba7cfe36586`
- Product optimization commit under test: `ff7f90bc9bcc99a16e5d8f76d4556d07965af3fc`

Both the published authority and the exact PLAY-078 source tip
`53ab9de79b923c588f9d6cd82788ec4f11cc4d80` are ancestors of the candidate.

## Scope and diagnosis

The test-adoption commit moves the 13 renderer-owned expectations to the
authoritative 34-road starter town, current developed/camera bounds, current
industrial story coordinates, and the exact retired golden-district reference.
It does not change camera policy or product rendering.

The product checkpoint repairs only the two admitted renderer regressions:

1. The three smaller road-enclosed natural regions now retain one deterministic
   low-contrast texture each and one bounded existing-foliage anchor overall.
   Their coordinates remain empty, buildable, action-free, and hit-testable.
2. Profiling showed the first state-changing pulse spent about 20 ms rebuilding
   the complete ambient corridor after only its typed activity source changed.
   The renderer now replaces only the bounded local-activity sublayer, preserves
   the static corridor and developed-ground identities, and updates diagnostics
   incrementally.

No camera behavior, activity threshold, simulation truth, generated-v4 asset,
shipping resource, Industrial L2 source, gameplay, UI, save, package, or shared
contract changed.

## Exact validation

- `swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
  - 66 tests, 0 failures, 42.591 seconds.
- `swift test --package-path Native/CitySimNative --filter 'CitySimulationTests.testRenderer'`
  - 7 tests, 0 failures, 1.631 seconds.
  - Ten state-changing pulses: 5,758 reused tiles, 2 updated tiles.
  - Total measured render time: 7.309 ms.
  - Average state-changing pulse: 0.731 ms, below the unchanged 2.1 ms ceiling.
  - World update: 4.632 ms aggregate; preparation: 2.890 ms aggregate;
    tile build: 1.736 ms aggregate; full-tree metrics: 0.000 ms.
- `swift test --package-path Native/CitySimNative`
  - 271 tests, 0 failures, 215.612 seconds.
  - Candidate-bound pulse average inside the full suite: 0.747 ms.
  - Full-suite renderer diagnostics: 1,843 opening nodes, 904 drawables,
    2 bounded ambient actions; no fallback regression reported.
- `git diff --check`
  - Pass.

The focused renderer suite also proves the 34-road topology, three current
enclosed natural regions, deterministic texture/foliage counts, empty-coordinate
buildability, activity source switching exactly once, static corridor identity
reuse, camera bounds, compact/default LOD behavior, typed target context, and
existing generated-v4 residency limits.

## Disposition

This is a clean Phase A checkpoint only. General PLAY-073 composition work is
frozen. Industrial L2 N/E/S/W remains the exclusive next renderer ingestion
slot and is still blocked on integration's independently approved source
handoff. No staged Industrial L2 candidate was built or implied here.
