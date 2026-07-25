# PLAY-027 Commercial L1 source-v04 review candidate

**Candidate:** `commercial_l01/variant-0` north/east/south/west `source-v04`

**Integration visual disposition:** materially passes Commercial L1

**Production selected:** no

**Expansion boundary:** Commercial L2 may begin only after this exact packet is
committed cleanly. Commercial L3/L4 remain blocked pending a separately frozen
and visually reviewed L2.

## Retained source identity

| Direction | Raw SHA-256 | Pixel SHA-256 |
|---|---|---|
| north | `a60220fc054165a0c54af70038bfcfbc16ac6768fd4f266c388ecfc27480379d` | `a72cbac78f69ca65e441dfdc688ae7ec4133d6a238c872e3ff59034337d80c4f` |
| east | `57db0fe3cbb696e85ac537baa63eff42c0766147eae9ea3179337da670cabda2` | `f42741f64b30a8e34db5de1bbfa9163362134d923ffbddf648ab970a9c1737fd` |
| south | `3786264c9543281d0377b776ce001f46eff8d7f8ead8b65c775d2de7eace016e` | `bc4011690e0a4b4e97cddb00afa9351db287a810aae9913275f8eabd59ced4a1` |
| west | `27bfa3228b8335d3bd9a223e0106beac32eeddb309c59e6a518ba9be72e6f58e` | `6595555d85207551f5d3179f4d998095aad00bd01b73308afdadd943b713874a` |

All four raw sources are byte-identical across three fresh rendering
processes. Exact retained-byte RGBA validation records matching visible/RGB
bounds, zero hidden non-magenta pixels, and alpha-visibility ratio `1.0` in
every direction. The earlier full-canvas viewer discrepancy and its initial
rejection remain preserved in `SOURCE-V04-REJECTION.md`.

## Deterministic normalization

The existing `normalize_calibration_asset.py` path ran twice without a code,
dependency, package, build, runtime, or shipping change. The durable second
run is retained under
`source-v04-review-candidate/normalized-repeat/<direction>/`.

| Direction | Block SHA-256 | Neighborhood SHA-256 | City SHA-256 |
|---|---|---|---|
| north | `a172b049427a88e688cbcb1e21bc3ad090692fb84e45d6141ac6f1200030af9b` | `019b3426fb453cd898a9e179b153b7272ffd96dab2f706faa8d5f62f012a2c9e` | `56f0c350208c6718e23c1aaadcf2b226cf5d3de2fdddf3f39454798273f719e6` |
| east | `555e813f5b24fea0bd3df70183f34caaf6defc1ca8951baf4f63092536414406` | `78958e37f17f25d651cdbf2deb21b65fdf2b898c9799071430a024f215fc9be4` | `2c1fd5e262d00d6333fff672fe391be52d9092a7450959c31070467a9481454f` |
| south | `cbad9d06c2aaa63f19f3059e6e4f68af724a94c886938794f0bac043a3265fba` | `a463f34d0edc929233be590af953aab0cff4b1a822f3922b1e2fc0bed44f59af` | `e4db22bd66d9e8ef1d99ed756af5a47edb7060d371cc717c3b208bd8d13fa10e` |
| west | `682ed34ad346ca4537898bd0a2628ff148db7ac6f71d6cec510e7c3af7626c0a` | `5a21b2fa753e419eb0fff32dc583163528223e7b4c8289637157381d5d4f327c` | `39eebe14f24b38eef19db235aea63ca797b872b4955b5df4b7b959586bdfe0a9` |

The twelve repeat reports all pass with one unique hash across their two
runs. `SOURCE-V04-NORMALIZED-ALL-UNIQUE.json` passes with twelve unique pixel
hashes across the twelve direction/LOD outputs. Every output has:

- alpha range `0...255`;
- zero opaque chroma pixels;
- zero visible magenta-spill pixels;
- passing canvas padding;
- a non-empty alpha bound;
- byte-identical primary and durable repeat output.

## Geometry, registration, and silhouette

`SOURCE-V04-SCENE-VALIDATION.json` passes with four unique descriptor hashes
and four unique scene-geometry IDs. Every source preserves:

- ground pivot `(768,896)`;
- contact polygon `(-28,-28) (28,-28) (28,28) (-28,28)`;
- southeast shadow vector `(2,1)`;
- fixed 2:1 orthographic projection and northwest key light;
- north/east/south/west sockets `(896,704)`, `(896,832)`, `(640,832)`,
  `(640,704)`;
- the direction-specific frontage edge and door base recorded in each scene
  report and source provenance;
- complete raw occupied bounds `[619,636,1029,906]`, including building,
  footprint plate, shadow, and frontage.

The normalized block registered crop is `[341,300,342,303]`, corresponding to
raw crop `[512,450,513,455]`. It includes all four alpha bounds without
clipping and provides a `144 x 128` pixel panel at native-2x scale.

The commercial-not-residential silhouette check passes for the evidence
packet: the flat parapet/coping, broad first-floor storefront glazing, deep
green canopy/entrance treatment, second-floor commercial rhythm, and rooftop
HVAC remain readable in color and grayscale. The identity does not depend on a
sign, pitched domestic roof, residential porch, or sibling transform.

## Review packet

All sheets use row-major north/east/south/west order:

| Review surface | SHA-256 |
|---|---|
| `SOURCE-V04-SOURCE-SCALE-REVIEW-CANDIDATE.png` | `4afdf8554ea5dc69964a49511110e530686b2a7e968f983799a5187e4d145420` |
| `SOURCE-V04-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `8809fb070be2be6e9d7dac282512444bcd92abbf652e5e5ea8454773c076bfa8` |
| `SOURCE-V04-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `01b76c4eeff541584c7b21989ce51c55e37061f7c10afc40759dce0fa68c32f0` |
| `SOURCE-V04-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `0b803a543dd9259db01793a44e6156dda051b179ae5b00ccd7a4cfa4e70ae412` |
| `SOURCE-V04-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png` | `3ffeebe5f1817b4b3f230a93f16572245380833c5fb0526c83e10beafbf0dd28` |
| `SOURCE-V04-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png` | `d8c813fd91c4b372015f3a6a0587fb716601c4facf6bcc6c4c3ca16ab5fd89f1` |

The sheet builder produced every surface twice with the exact same six file
hashes. Its Core Image software grayscale path failed before output on this
host. The task-owned tool now uses a fixed Core Graphics Rec.709 integer-luma
conversion over canonical premultiplied RGBA bytes. This is deterministic,
adds no dependency, and does not change any raw or normalized source pixel.

This packet remains non-shipping and `productionSelected: false`. It makes no
renderer, atlas, manifest, package, build, gameplay, simulation, UI, save, or
Residential mutation.
