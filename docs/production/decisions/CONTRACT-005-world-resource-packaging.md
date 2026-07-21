# CONTRACT-005: Stage the SwiftPM world-resource bundle

**Status:** Approved and implemented by integration

**Date:** July 21, 2026

## Decision

Every staged CitySim app must contain the SwiftPM executable resource bundle
`CitySimNative_CitySimNative.bundle`. Staging fails if the bundle, its world
atlas manifest, or a known atlas probe is absent.

The bundle is copied without renaming to the staged `.app` root. SwiftPM's
generated `Bundle.module` accessor resolves
`Bundle.main.bundleURL/CitySimNative_CitySimNative.bundle`; placing only the
key art under `Contents/Resources` is insufficient, and renaming the bundle
would break that generated lookup.

The candidate manifest and `--print-identity` output include the exact staged
resource-bundle path so visual proof can be tied to the resources actually
loaded by the process.

## Why

PLAY-022 Gate A proved that renderer tests could load the world atlas from the
SwiftPM build directory while the staged app silently omitted that bundle. The
result was a false build success: the exact app presented for visual review
could not load the candidate art.

This contract makes declared world resources part of the staged application
rather than an incidental test-only dependency.

## Compatibility and affected lanes

- The change is additive and does not alter simulation, saves, commands,
  preferences, bundle identifiers, executable identity, or data roots.
- Every lane uses `script/build_and_run.sh` and receives the same packaging
  behavior.
- Staged bundle size increases by the copied resources. Renderer candidates
  must continue to report size, RSS, texture memory, and frame budgets.
- Candidate isolation remains governed by CONTRACT-004; the resource path is
  nested inside each already-unique staged `.app`.

## Validation

Integration verified on `master` that:

- `bash -n script/build_and_run.sh` passes;
- `./script/build_and_run.sh --stage-only` succeeds;
- the staged manifest reports the exact resource bundle path;
- `WorldAssets.atlas/manifest.json` and `terrain_grass_0.png` exist inside the
  staged bundle;
- the staged SwiftPM bundle contains 71 files and occupies approximately 336
  KB on the accepted pre-generative atlas.

PLAY-022 must synchronize this contract, rerun the exact staged app, and prove
that its generated assets load from the packaged bundle. Test-only or manually
copied resources are not acceptance evidence.

## Rollback

Revert this contract and its build-script commit together. Do not work around a
rollback by changing `Bundle.module`, copying individual PNGs, or loading art
from an absolute development path.
