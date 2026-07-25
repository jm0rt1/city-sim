# PLAY-063 Independent Candidate Validation

All commands were executed from exact combined candidate
`f928696a84676032b20c6306b14d943592e219fb` after a clean fast-forward from
the immutable preregistration.

## Ancestry and staging

The following were all proven ancestors of the exact candidate with exit `0`:

- `b9f2aedc985d31329c49d259cbbd1a303b021047`;
- `41a22c8d36fda7fbfac27747bdff0ab59c981c74`;
- `02612e414912fdabcab858b0ca97e1f5edbc2757`;
- `7ea9971f58f9c86cb17c1b978c7af3ae9b230cae`;
- `79668c347e58d602f9627c73cb09e3272a83ef57`; and
- `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`.

`./script/build_and_run.sh --verify` passed and reported exact commit
`f928696`, quality candidate ID `playtest-quality-wf967be0ab5b4`, the
candidate-specific bundle/defaults/data identities, and live PID `94284`.
`bash -n script/build_and_run.sh` passed.

## Independent suites

| Check | Result |
|---|---|
| `swift test --filter WorldRenderingTests` | 55/55 passed, 0 failures, 30.235 seconds |
| `swift test` | 226/226 passed, 0 failures, 108.929 seconds |
| generated-v4 pack validator | passed; zero failures |
| production geometry validator | passed; zero failures |
| two independent pack builds | manifest and all four page bytes identical |
| source/staged generated manifest | byte-identical |

The focused suite independently exercised all four authoritative Industrial
frontages and every semantic LOD, save/load/undo identity, deterministic
frontage priority, roadless rejection, exact compact safe viewport, overlays,
construction/condition/recovery, Reduce Motion, residency, and fallbacks.

## Resource, geometry, and performance result

- Four atlas pages total.
- Four unique Industrial raw identities and twelve unique normalized LOD
  identities.
- Staged/source manifest parity: true.
- Active-plus-adjacent decoded bytes:
  12,582,912 city and 41,943,040 neighborhood/block.
- Repeated LOD high-water:
  41,943,040 bytes in the renderer test and 24,752,080 bytes in the geometry
  validator; both below the 128 MiB ceiling.
- Resident textures:
  three.
- Fallbacks:
  zero.
- Geometry inventory:
  48 assets / four production inventories.
- Building/road collisions:
  zero.
- Reciprocal-ground collisions:
  zero.
- Entrance/prop-exclusion collisions:
  zero.
- Candidate focused cold profile:
  5.907 ms total, 4.233 ms world update.
- Candidate full-suite cold profile:
  5.702 ms total, 3.854 ms world update.
- Frozen baseline cold profile:
  5.632 ms total, 4.039 ms world update.
- Full-suite total-render delta from baseline:
  +1.24%; focused repeat:
  +4.88%; both below the 20% guard.
- Unchanged-pulse soak:
  4,286 pulses, 0.0006 ms average.
- Highest observed live quality RSS:
  230,208 KiB on a launch sample; settled samples were lower. This is below
  the accepted 333.8 MiB ceiling and showed no continuing high-water growth.

Exact machine-readable results are retained in `validation/`. The first
unprivileged full-suite attempt failed before test execution because the
sandbox denied Swift's module-cache write. The authoritative rerun used the
normal approved Swift cache access and passed 226/226; no test result was
discarded or recharacterized.
