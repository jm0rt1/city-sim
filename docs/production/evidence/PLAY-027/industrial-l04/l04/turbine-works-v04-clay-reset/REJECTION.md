# PLAY-027 Industrial L4 Turbine Works V04 clay reset

Disposition: `REJECTED_CLAY_PROPORTION_GATE`

This is a non-authoritative clay-only checkpoint. It contains no scene
descriptor, material library, props/details, SceneKit/Metal source render,
ImageGen output, or normalization output.

- `sourceAuthority`: `false`
- `productionSelected`: `false`
- generator source SHA-256:
  `98bd99778efdc2e1998d755c3044af08038ca994d18670455aafc39c53245413`
- compiled binary SHA-256:
  `1b0887aeced958d791d7e298795b1c4c5f7ea0022835448fd1beb8336d38ba30`

Compile command:

```text
swiftc -module-cache-path /tmp/play027-l4-turbine-clay-cache -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4TurbineClayReset.swift -o /tmp/build-industrial-l4-turbine-clay-reset
```

The generator was executed exactly once:

```text
/tmp/build-industrial-l4-turbine-clay-reset --output-root /tmp/play027-l4-turbine-clay-reset-v04
```

It exited nonzero with:

```text
error: N: hall ratio 1.5679442508710804; N: stack share 0.09180600270017655; E: hall ratio 1.5679442508710804; E: stack share 0.09362862895369228; S: hall ratio 1.5679442508710804; S: stack share 0.09644486666577465; W: hall ratio 1.5679442508710804; W: stack share 0.09632114174227947
```

The four directions pass the 42-unit non-stack height, four-peak,
control-wing-height, and three freight-opening width gates. They fail both
binding silhouette constraints:

- hall projected width / visible height is `1.5679442508710804`, below `2.4`;
- stack silhouette share is `9.18%` to `9.64%`, above `8%`.

Literal inspection of the 192x128 sheet confirms the campus remains too small
and the rear stack too dominant. No material/detail work or second proportion
iteration was attempted.

Exact retained outputs:

- `TURBINE-V04-CLAY-NESW-EQUAL-SCALE.png`:
  `e344561f80166c3ed6a02b9eaacad64f5af4c5a381dcbcc8c20a7559c276cfb5`
- `TURBINE-V04-CLAY-NESW-192x128.png`:
  `f31c953d4347f7fbf7c32b4bec119a71d16ee97f09a594830bbd14a921702c35`
- `CLAY-METRICS.json`:
  `8a32768261d48047a0d1b6b961da2d6857074f41b1b0fd77a49fda963a0c6931`
