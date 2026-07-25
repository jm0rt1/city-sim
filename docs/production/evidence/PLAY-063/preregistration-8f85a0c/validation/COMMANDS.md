# PLAY-063 Preregistration Validation

All commands ran from the quality worktree at exact published authority
`8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`.

## Authority and parity

```text
git rev-parse HEAD
git rev-parse origin/master
git rev-list --left-right --count HEAD...origin/master
```

Result: exact `8f85a0c` / exact `8f85a0c` / `0 0`.

```text
git diff --quiet 1799fbc..8f85a0c --
  Native/CitySimNative/Sources
  Native/CitySimNative/Resources
  Native/CitySimNative/Package.swift
  script/build_and_run.sh
```

Result: exit `0`; shipping product/build tree unchanged from accepted product.

## Staging

```text
./script/build_and_run.sh --verify
```

Result: passed; exact commit, branch, candidate ID, bundle ID, data root,
bundle, executable, resource bundle, manifest, and PID reported. The manifest
is retained at `identity/staged-baseline.manifest`.

```text
cmp -s \
  Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json \
  dist/CitySim-playtest-quality-wf967be0ab5b4.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas/generated-v4-manifest.json
```

Result: exit `0`; both SHA-256
`c9351451928e035c0631b074d38fc55156325e5fcd19d3ebd4b104c5f90d8aa8`.

## Tests

```text
cd Native/CitySimNative
swift test --filter WorldRenderingTests
```

Result: **52/52 passed**, zero failures, 28.352 seconds.

```text
cd Native/CitySimNative
swift test
```

Result: **223/223 passed**, zero failures, 110.348 seconds.

## Live proof

The exact app was launched once per route with `/usr/bin/open -n`, isolated
`CITYSIM_DATA_ROOT`, explicit regular or compact environment, and optional
proof scale/Reduce Motion environment. `ps eww` bound each frame to its exact
PID, executable, root, viewport, and environment. The fixture was loaded with
Command-O, the transient load message was allowed to expire, and keyboard
navigation selected Industrial block 15,12.

Pointer selected Pollution from the layer menu. Keyboard entered Focus City,
opened Details, and traversed FKA focus. Every exact PID was terminated with
SIGTERM. Final exact-executable process search returned no live match.

## Final packet validation

The committed packet must pass:

```text
git diff --check
test "$(wc -l < ledgers/industrial-direction-lod-matrix.csv)" -eq 13
shasum -a 256 <all retained evidence files>
git status --short --branch
```

The twelve data rows are exactly four directions by three LODs. Binding regular
and compact dimensions, distinct LOD hashes, and all evidence hashes are
recorded by `SHA256SUMS`.
