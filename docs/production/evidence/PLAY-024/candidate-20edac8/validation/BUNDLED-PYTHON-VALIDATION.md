# Bundled Python Validator Reproduction

- **Date:** July 24, 2026
- **Exact product:** `20edac880a6f22d902e353d5ce939028f753de84`
- **Interpreter:** `/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
- **Pillow:** `12.2.0`
- **Dependency changes:** none

## Commands

```text
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py \
  --atlas Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas \
  --staged-atlas dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas \
  --report /private/tmp/play024-bundled-python-world-pack.json

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py \
  --report /private/tmp/play024-bundled-python-geometry.json
```

## Results

- World-pack validator: passed with zero failures, source/staged identity true,
  84 payload checks, 84 extrusion checks, 974 packed-overlap checks, 133 source
  inventory entries, and all three LOD residency sets within budget.
- Geometry validator: passed with zero failures, 324 reciprocal ground-contact
  checks, 36 building/road-setback checks, and 256 entrance/prop exclusion
  checks.
- Generated world-pack report SHA-256:
  `b9ac6497e65f579d3e498ae84cd4b3ccb9aa09b08d34b51ae194b3b5778215f0`.
- Generated geometry report SHA-256:
  `059031e2a05930b115982773220b05812b35da8550bb46e63346a9549a9eab04`.
- Both generated reports are byte-for-byte identical to the retained
  `world-asset-pack.json` and `production-geometry.json`.
- The staged candidate manifest identifies product `20edac8`, candidate
  `world-rendering-w5f893ad1da1b`, and the packaged SwiftPM resource bundle
  used by the world-pack validator.
- `git diff --quiet 20edac8..4e0bb39 -- Native/CitySimNative` returned success:
  the evidence commit changed no staged product source.
