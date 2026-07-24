# PLAY-022 Gate A — staged resource packaging blocker

**Observed:** July 20, 2026 at candidate `eac7ddf`

Gate A is implemented and loads from SwiftPM in renderer tests, but it cannot
reach the required exact staged-app visual gate. `script/build_and_run.sh
--verify` stages only the renamed executable and `CitySim-KeyArt.png`. The
generated `CitySimNative_CitySimNative.bundle`, including the complete
`WorldAssets.atlas`, is left beside the debug executable and is absent from the
staged `.app`.

## Reproduction

1. Run `./script/build_and_run.sh --verify` on commit `eac7ddf`.
2. Confirm the source resource exists at
   `Native/CitySimNative/.build/debug/CitySimNative_CitySimNative.bundle/WorldAssets.atlas/golden_district_block.png`.
3. Inspect `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/Resources`.
   It contains only `CitySim-KeyArt.png`; there is no SwiftPM resource bundle.
4. Inspect the live app. `GoldenDistrictRenderer.makeDistrict` cannot resolve
   its texture, so the guarded plate is empty and the systemic renderer remains
   visible. The focused unit tests pass because SwiftPM supplies the bundle to
   the test product.

## Shared-contract proposal

- **Why blocked:** the app launch/build script is integration-controlled, and
  the current staging contract drops every SwiftPM executable resource. This
  prevents the claimed world resource pipeline from existing in the app that
  must be visually scored.
- **Smallest change:** after SwiftPM reports `BUILD_DIR`, copy
  `$BUILD_DIR/CitySimNative_CitySimNative.bundle` recursively into
  `$APP_RESOURCES/CitySimNative_CitySimNative.bundle`; fail staging when the
  declared package resource bundle is missing. Do not rename the bundle,
  because SwiftPM's generated `Bundle.module` locator expects that name.
- **Affected lanes / risk:** all lanes use the shared staging script. The change
  is additive and low migration risk, but increases staged bundle size by the
  atlas and must preserve unique candidate identity and exact-process rules.
- **Compatibility proof:** add a staging assertion for the copied manifest and
  one atlas PNG, rerun `build_and_run.sh --verify`, confirm Gate A in the live
  default and compact app, then run the focused renderer suite, full suite,
  `bash -n script/build_and_run.sh`, and candidate-isolation validation.

No manual resource copy is presented as candidate evidence. Gate A remains
open until integration approves and lands this packaging contract, this branch
synchronizes it, and the exact staged app passes independent visual scoring.
