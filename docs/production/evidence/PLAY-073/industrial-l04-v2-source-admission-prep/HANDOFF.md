# PLAY-073 Industrial L4 v2 source-admission prep

## Disposition

`READY_FOR_INTEGRATION_REVIEW_NONSHIPPING`

This is a self-contained, add-only renderer test/evidence slice based on
published master `f9cb5fbae1be459ba297a8605347c4174f912ba0`. It does not
depend on `IndustrialL4IntakeTests.swift` or any other legacy preparation file.

The older branch candidate through `62ea57faa42d7324809f028bfc699e069ecd7f31`
remains preserved in history but is **not** an integration-ready range. Its
base includes legacy preparation surfaces absent from published master.

## Exact adoptable boundary

- synchronization merge:
  `c833f1c4e5c6a2f226d28523e0bfea9fa2e26fec`;
- self-contained harness:
  `139b2429a7bd629e69156a216b57a5e14455ea17`;
- harness path:
  `Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL4V2SourceAdmissionHarnessTests.swift`;
- harness SHA-256:
  `c2d67e04d3f930d71b695bc1456c31342e777ede4b21be978ff82e89a141f7ea`.

Commit `139b2429` adds exactly one uniquely named test-target file. It imports
only Foundation, CryptoKit, and XCTest. It does not reference legacy
`IndustrialL4*` support types, `IndustrialL4IntakeTests`, product catalogs, or
runtime renderer types.

## Governed v2 bindings

The harness pins the exact published source-stage inputs:

- schema v2:
  `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7`;
- semantic validator:
  `7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340`;
- canonical RGBA decoder:
  `2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab`;
- accepted-master non-alias loader:
  `2c44bc3a4ffe3fdfc68a477b70f3af9478122e9b796543f32a154859ac300a39`.

A worker direction packet may state only:

- `stage = source_candidate`;
- `candidateReadyForIndependentReview = true`; and
- `sourceReady`, `integrationAdmitted`, `rendererQuarantined`,
  `productionSelected` all false.

Worker self-admission fails direction-locally. Renderer quarantine requires a
separate strict-shape Integration receipt binding the exact worker packet
path/hash, content commit, decoded RGBA hash, semantic validator and PASS
result, independent technical ACCEPT, and literal-scale ACCEPT. Missing
receipts, missing fields, unexpected top-level/nested fields, or binding drift
fail closed.

## Non-shipping preparation

The four-direction join validates:

- four unique logical direction identities;
- 12 unique City/Neighborhood/Block LOD hashes and logical atlas slots;
- 32 unique D4 identity/transform fingerprints;
- exact source-pixel pivot and N/E/S/W frontage sockets;
- no fallback, source alias, LOD alias, mirror, rotation, or transformed
  sibling;
- one deterministic sole-road fixture coordinate and three camera expectations
  per direction; and
- `ready_for_atomic_assembly` only after four separately admitted directions.

Zero through three directions remain inactive or quarantined incomplete. Even
at exact four-of-four, runtime mapping, shipping resources, and production
selection remain false.

## Focused validation

Command:

```text
swift test --package-path Native/CitySimNative --filter IndustrialL4V2SourceAdmissionHarnessTests
```

Exact-candidate result: **4 passed, 0 failed** in **0.085 seconds** after an
18.34-second clean relink/build.

The focused gate covers separate admission, worker self-admission, missing and
unknown receipt fields, fallback, registration drift, source alias,
D4-transform alias, 0/1/2/3/4 quarantine states, 12 LOD identities, 32 D4
identities, deterministic fixture preparation, and nonactivation.

No full suite or staged app was run under the published tiered intake rule.
No source art, atlas, manifest, runtime mapping, fixture bytes, package,
product, gameplay, UI, simulation, save, or shipping resource changed.
