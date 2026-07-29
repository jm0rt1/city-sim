# Industrial L4 renderer quarantine preparation authority

**Published baseline:** `af995850f0b20603c89ec7fdfda56245153a7f94`

**Renderer prerequisites:** `5d81479453dbd574ab3a880db3e37b227ed5a1d5`,
`cdcd1e92b2864f7f5c5ad879ee015ca2179459bd`, and
`e5998bd5b892b75351f78b60e3a8ec33d0a64eda`

**Governing contract:** `CONTRACT-021` revision 2

**Disposition:** `AUTHORIZED_NON_SHIPPING_DIRECTION_QUARANTINE_PREP`

The existing fail-closed L4 intake freezes identities, LOD slots, registration,
camera expectations, and the zero-direction inactive state. It does not yet
bind a returned direction to exact art bytes, independently reject aliases or
transforms, preserve accepted siblings, or prove that one through three
directions remain inactive while four exact directions become eligible for
atomic assembly.

The external fixture intake at `cdcd1e92` is valid only on the unaccepted R2
renderer chain and is explicitly not independently adoptable on master. This
authority preserves that boundary.

## Authorized surfaces

Renderer may add only test/evidence-owned, non-shipping L4 quarantine records
under:

- `Native/CitySimNative/Tests/CitySimNativeTests/`;
- `docs/production/evidence/PLAY-073/industrial-l04-direction-quarantine-v1/`.

It may extend the task-owned non-shipping intake descriptor introduced at
`5d814794` only if required for the validator and only on the renderer branch.

Do not edit source art, accepted art packets, atlas pages, shipping manifests,
runtime selection/mapping, renderer presentation, `Package.swift`, QA
fixtures, build scripts, or staged resources.

## Required quarantine packet

Define a machine-readable direction packet binding:

- schema version, family, level, variant, and direction;
- CONTRACT-021 revision and future appearance-lock commit/hash fields;
- exact source-art candidate commit, source key, decoded RGBA hash, and three
  distinct normalized LOD hashes;
- provenance/toolchain record hashes;
- footprint, pivot, socket, frontage, alpha/chroma/hidden-RGB, occupied bounds,
  canvas, and shadow/contact declarations;
- explicit authored-direction and no-alias/no-mirror/no-rotation/no-transform
  evidence derived from packet content rather than trusted booleans;
- `sourceReady`, `productionSelected`, and quarantine disposition.

The validator must reject missing or duplicate directions, source/LOD aliases,
transformed siblings, incomplete provenance, contract/appearance-lock drift,
registration/frontage drift, fallback, and any production-selected input.

## Mutation matrix

Prove independently:

- zero accepted packets: `inactive`;
- one, two, or three unique accepted packets: `quarantined_incomplete` with
  the accepted directions preserved and the missing directions named;
- four exact unique accepted packets: `ready_for_atomic_assembly`;
- no case mutates or selects runtime/shipping resources.

Use deterministic synthetic packet fixtures only. They are validator evidence,
not source-art acceptance and not staged-app proof.

## Commit cadence

1. Commit the packet schema and validator/test boundary.
2. Commit the deterministic 0/1/2/3/4 mutation matrix and rejection cases.
3. Commit the non-shipping evidence ledger and clean handoff.
4. Stop for Integration review.

Renderer must not self-accept the packets or infer that any Industrial L4
direction exists. Actual per-direction quarantine begins only after World Art
returns an independently accepted exact source. Atomic assembly, staged
fixture work, production selection, final QA, integration, and push remain
blocked.
