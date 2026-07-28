# PLAY-027 Industrial L4 Turbine v07 proof-binding rejection

Disposition: `REJECTED_PREPIXEL`

This packet preserves the first descriptor-derived proof attempt after rejected
candidate `104027f29fce44fb734c010625a4f8f8fc509c2c`. It is not source authority,
production selection, or raw-source evidence.

## Boundaries

- accepted program authority: `3c160e21a917adffd4bf148351a1657184154669`
- accepted clay authority: `90f3c0e8d3c6eab62de2487b84ebf211a2403cd6`
- rejected local-plan proof: `104027f29fce44fb734c010625a4f8f8fc509c2c`
- preserved rejection commit: `72c8e82728580cf84589ad6ec26fc0ed0035d9ba`
- sourceAuthority: `false`
- productionSelected: `false`
- SceneKit processes: `0`
- Metal processes: `0`
- normalizer processes: `0`
- ImageGen calls: `0`

## Replay

The task-owned builder compiled with warnings as errors:

```text
swiftc -module-cache-path /tmp/play027-l4-turbine-v07-compile-cache \
  -parse-as-library -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4TurbineClayReset.swift \
  -o /tmp/build-industrial-l4-turbine-v07-prepixel
```

The single governed pre-pixel replay was:

```text
/tmp/build-industrial-l4-turbine-v07-prepixel \
  --output-root /tmp/play027-l4-turbine-v07-run-k \
  --repository-root /Users/James/.codex/worktrees/0648/city-sim
```

It failed closed:

```text
N: compact median 55
N: freight/staff semantic visibility
E: compact dark share 0.12666200139958012
S: compact dark share 0.12758620689655173
W: compact median 55
W: compact dark share 0.10119940029985007
W: freight/staff semantic visibility
```

The hard gates were not lowered or removed.

## Semantic result

East and South preserve three complete freight regions and a distinct staff
entry. North freight A retains only `8.125 x 3.75` compact pixels. West freight
C retains only `8.125 x 5.5` compact pixels. Both fail the required `8 x 8`
semantic visibility gate. North and West therefore require genuinely
independent road-connected courtyard/foundry compositions rather than another
incremental cut in the shared hall.

## Exact hashes

- builder source: `33d94e3ce8156b6a56e561f44d848ce4fc1e14082346857d0a5a1213316901e3`
- compiled builder: `e7e37b9212e2d57bcf76159741be9f1b877b0aafd1814701884744d401c77dbe`
- `PREPIXEL-VALIDATION.json`: `858061b193bdd9fe4e18c3bd71575f7be8fa9e995b9ebf18b2c19cb22b84da06`
- `SOURCE-COLOR-NESW.png`: `64bc9182add7ef2d2b706535d3d68e58327d8915669f1347762cf6d1153a17e1`
- `FREIGHT-STAFF-VISIBILITY-NESW.png`: `4d7194bb31832a2f8108fe245ad89e7535b10612de96e7a2f933ddcded49e31d`
- ordered packet file-hash digest before this receipt:
  `12f0c9502ac524cb8adcb8e8c70646761f743a7246faa9463e4e5ff81eaecadd`

The next authorized action begins only after this exact failed state is durable.
It may preserve the sound East/South treatment while redesigning North and West
as independent compositions. No raw-source process is authorized.
