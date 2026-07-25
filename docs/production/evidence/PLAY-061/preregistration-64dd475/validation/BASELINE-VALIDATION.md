# PLAY-061 Frozen Baseline Validation

The preregistration does not rerun or mutate the exact accepted product.
Product/build parity between `64dd475` and published preregistration authority
`91f8859` passed with an empty diff across:

- `Native/CitySimNative/Sources`
- `Native/CitySimNative/Resources`
- `Native/CitySimNative/Package.swift`
- `script/build_and_run.sh`

The exact product's independent accepted PLAY-058 validation is retained at:

- `docs/production/evidence/PLAY-058/candidate-64dd475/DISPOSITION.md`
- `docs/production/evidence/PLAY-058/candidate-64dd475/identity/IDENTITY.md`
- `docs/production/evidence/PLAY-058/candidate-64dd475/validation/full-native-suite.log`
- `docs/production/evidence/PLAY-058/candidate-64dd475/validation/world-asset-pack.json`
- `docs/production/evidence/PLAY-058/candidate-64dd475/validation/production-geometry.json`

Frozen comparison results:

- full native suite `219/219`, zero failures;
- rendering group `48/48`, zero failures;
- governed staged identity passed;
- four-page pack limit passed;
- zero fallback;
- deterministic source/staged parity passed;
- repeated LOD high-water 41,943,040 decoded bytes;
- cold world update 3.806 ms and total 5.643 ms; and
- 4,286-pulse soak average 0.0007 ms.

The future exact PLAY-060 candidate must independently rerun focused renderer
and asset tests, the full native suite, staged verification, deterministic
two-build pack identity, geometry/occlusion validators, three-cycle residency
and RSS, cold/update/render timing, and source-to-staged hash parity. Historical
baseline validation is comparison authority, not candidate acceptance.
