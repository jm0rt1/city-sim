# PLAY-027 Turbine Works v03 pre-pixel rejection

Disposition: `REJECTED_PREPIXEL_VISUAL_GATE`

The mechanically retargeted v03 builder compiled, but its retained integration
probe reproduced the returned Industrial L4 v02 compact orthogonal tower
grammar. It does not visually translate the selected Turbine Works concept.

Binding visual defects:

- no long, low sawtooth high-bay hall;
- no broad foundry-campus silhouette;
- no visually dominant three-bay freight frontage;
- no distinct low warm-masonry control wing;
- rooftop clutter and compact tower massing dominate;
- the supposed source-scale output is byte-identical to the returned v02
  analytic source panel.

## Exact compile

```text
swiftc \
  -module-cache-path /tmp/play027-l4-turbine-rejected-cache \
  -parse-as-library \
  -warnings-as-errors \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift \
  Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4TurbinePrepixel.swift \
  -o /tmp/build-industrial-l4-turbine-rejected
```

Result: `PASS`

- builder SHA-256:
  `b08c642836ce33a712caf26e1d605359714b73c5703eced80d3f815d33be0ae7`
- toolchain SHA-256:
  `5a2d340a9ce5333c6a3ab59304c776e407b513b5f55eb89eae58fa843bfb1fd0`
- compiled binary SHA-256:
  `a0094bc9bf6978822c4c5dce1d627766353726fab9a8e3fea50a0d3c1245b12b`

## Retained integration probe

The independently run probe used the exact required regular and compact staged
frame hashes and stopped at:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level:
L3-to-L4 silhouette change target failed
```

The 27 retained generated files are under
`rejected-integration-probe/`. They include the exact material library, four
scene descriptions, and all 22 panels emitted before the fatal gate.

Key identities:

- material library:
  `85fa84bfd947741dd1dd364fd08c7cacd9654b6c2f09a7aaa780bac95af9b2a6`
- North descriptor:
  `b3d183f607602690673098065401287278ba021e5eb79a82a699dc004b02d98f`
- East descriptor:
  `1e83b391cb748406bd36ebe571281c53feb97644e4a0401ffe0088957cf7e1e0`
- South descriptor:
  `c0672a5e81f78dc41273169f226dfdbf749ef174dd9ea4c8082fdb1ed96e17a1`
- West descriptor:
  `e6e85827eae94c5375fd08648f9806b17eb678903f644020a08f5e0ff4968bb7`
- source-scale color panel:
  `cf8095c39e6a23e9f352d9c2763673b7a0600074daad566dc30b177f18a12d93`
- clay panel:
  `c66c9819ba3221176feaacf4a90ffc93971a57caa90987a463d335fdf90988ee`
- compact color panel:
  `eb5089df5f1de31fca388474c8f7b24f1890efa996f2d3cf61c65643fa6231f5`

No raw source render, ImageGen, normalization, source authority, production
selection, renderer, shipping, package, runtime, or shared-manifest process or
mutation occurred.

`sourceAuthority=false`

`productionSelected=false`
