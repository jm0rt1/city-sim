# PLAY-073 Industrial L4 v2 source-admission prep

## Canonical Integration receipt adoption

Published Integration authority
`8a3954160b28d580439db3df0aa5fae780d833e5` establishes the first canonical,
independently approved source-admission receipt boundary. Renderer merged that
authority without conflict at `b7dfeadf4ddedcaab9a80744c06ee86698eb3b39`
while preserving exact L3 candidate
`cc3112fee68948d8f723c00810077b6abafb53db` as an ancestor.

The self-contained synthetic intake harness now pins:

- receipt schema
  `docs/production/evidence/INTEGRATION/industrial-l04-source-admission-receipt-schema-v1.json`,
  SHA-256
  `08ad183eb90dc8eb14567a432c00841b010f90f8d8e4d359b60d4735c4ca4f66`;
- strict Integration validator
  `.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_source_admission_receipt_v1.py`,
  SHA-256
  `497f4e696cb6da3740e9dd60877cd25ea631268df1124513b1468ad6d51158cf`;
- all 24 canonical top-level fields and their exact nested shapes; and
- a source context separate from Renderer state, binding the direction-owned
  source branch, exact source HEAD, and `clean` state.

Direction-local validation rejects a source branch that does not match North,
East, South, or West ownership, unknown nested `sourceContext` fields, missing
canonical fields, and any Renderer/production/shipping authority escalation.
The harness does not rerun Integration's Git/source-worktree validator or
infer source admission; it consumes only an already-published Integration
receipt and cross-binds its direction, logical ID, worker packet, content
commit, decoded identity, semantic validator, and dispositions to the
synthetic Renderer packet.

Focused validation:

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/play073-l4-admission-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/play073-l4-admission-swift-cache \
swift test --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests
```

Result: **17 executed, 15 passed, 2 expected no-live-input skips, 0 failed**
in **0.188 seconds** after a **1.91-second** focused build.

The exact synthetic North caller-path replay passed **1/1** in **0.002
seconds** and retained deterministic sorted-JSON-plus-newline receipt SHA-256
`1de39bbef86fbef3a9510eec69354020e4a9106c8a19ba432b319b15336d0826`.
The published Integration validator suite separately passed **17/17** in
**0.636 seconds**. JSON parsing, `bash -n`, and the existing path-confinement
checks pass.

Harness SHA-256:
`5ef713433219fe9f178a346ab57b15b917be9f858157b67ed41a808037ae9bc2`.
Synthetic canonical admission SHA-256:
`b2e98cbca6684ce8a0b1efee0ee4a162b21d1cf0ba0d15ad9d508b81b80ba666`.

There are still zero live Integration source-admission receipts. No source
packet or pixel was consumed, no direction was actually quarantined, and no
runtime, atlas, manifest, shipping, fixture, package, product, staged-app, or
QA surface changed. The historical preparation below remains retained; this
section is the current candidate-bound handoff.

## Direction-path confinement addendum

The focused descendant authorized against frozen Renderer base
`270eb7515c1cc950f3bfe4b6687fd3ee788122c3` makes the direction-local caller
boundary fail closed without changing its schema or receipt bytes:

- the claimed root, worker packet, Integration admission, evidence root, and
  quarantine receipt output are canonicalized before use;
- lexical and canonical paths must remain beneath the claimed repository root,
  and receipt output must additionally remain beneath
  `docs/production/evidence/PLAY-073/`;
- every path component beneath the canonical claimed root is checked with
  `lstat`; symlinks are rejected even when they resolve inside the root;
- dangling final receipt-output symlinks are rejected before any write, and
  the absent external target remains absent; and
- packet and admission inputs plus existing receipt outputs must be regular
  files, while existing intermediate components must be directories.

North, East, South, and West each exercise deterministic positive admission
and receipt replay, packet/admission symlink rejection, non-regular input
rejection, intermediate output symlink rejection, dangling final output
symlink rejection, directory-output rejection, and lexical evidence-root
escape rejection.

Focused validation:

```text
swift test --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests
```

Result: **14 executed, 12 passed, 2 caller-supplied entrypoints skipped,
0 failed** in **0.107 seconds** after a **2.11-second** focused build.
The explicit synthetic North caller-path wrapper then passed **1/1** in
**0.005 seconds** and reproduced the unchanged receipt SHA-256
`3bc7636f98afed07cc8b0b5f5fc0302d032be107acbb6e69af950459789173d4`.
`bash -n`, JSON parsing, and `git diff --check` also pass. No full suite or
staged app was run under the directional-intake tier.

Hardened harness SHA-256:
`8bcf0978185b6a906be04c21bc71f34d5c115bc820547aaebfa360ef3b9fd3c4`.
The wrapper and all synthetic packet/admission/receipt bytes remain unchanged.

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
