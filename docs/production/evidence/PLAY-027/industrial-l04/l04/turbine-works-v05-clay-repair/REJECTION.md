# PLAY-027 Industrial L4 Turbine Works V05 clay repair

Disposition: `REJECTED_CONTROL_WING_PROPORTION_GATE`

This is the exact result of the one authorized deterministic clay replay.
It is non-authoritative and was not tuned or rerun after failure.

- `sourceAuthority`: `false`
- `productionSelected`: `false`
- generator source SHA-256:
  `f8a123db26a9e578653fabd7494a868f71b67f8ea5a5d1c8e1f2f6dc1b4c5ff2`
- compiled binary SHA-256:
  `e02d3f9b97a8dc722e5121ebb3844ec0af6d68af44f7b1e90abca040cb172241`
- generator size: `537` lines

Compile command:

```text
swiftc -module-cache-path /tmp/play027-l4-turbine-clay-v05-cache -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4TurbineClayReset.swift -o /tmp/build-industrial-l4-turbine-clay-v05
```

The generator was executed exactly once:

```text
/tmp/build-industrial-l4-turbine-clay-v05 --output-root /tmp/play027-l4-turbine-clay-v05
```

It exited nonzero with:

```text
error: N: control/hall 0.625; E: control/hall 0.625; S: control/hall 0.625; W: control/hall 0.625
```

Five governed metrics now pass in every direction:

- hall projected width / wall-plus-roof height: `3.6` (`>=2.4`);
- non-stack maximum height: `22` world units (`<=42`);
- stack silhouette share: `6.19%` to `6.43%` (`<=8%`);
- four readable sawtooth peaks;
- three freight openings: `9.3815` compact pixels each (`>=8`).

The retained 10-unit control wing is `62.5%` of the lowered 16-unit hall,
exceeding the `55%` control-wing gate. Literal source and 192x128 inspection
shows the stack is subordinate and the repeated roof rhythm is improved, but
the failed numeric invariant prevents a PASS candidate. No materials,
descriptors, props/details, SceneKit/Metal source render, ImageGen call,
normalization, or second clay replay occurred.

The generator retained its compact v04 filename literals; they are preserved
unchanged rather than relabeled after the failed run:

- `TURBINE-V04-CLAY-NESW-EQUAL-SCALE.png`:
  `bbc9fbedd7c11c233a0e09601594b4f3a2dde979a5d5de17b6307e52cfd55807`
- `TURBINE-V04-CLAY-NESW-192x128.png`:
  `68aec443701f5553b40a2ed51e26ad3295900a8ea94e5787d1a6cc68cacb7a0e`
- `CLAY-METRICS.json`:
  `b1663b7611887d9e0f5bed9527b262eee695e9169d086bcdeb2c5612df440efc`
