# PLAY-073 proposal: `assembly-input-manifest-v1`

## Decision requested

Integration should own and publish one immutable
`assembly-input-manifest-v1` only after all four Industrial L4 directions have
separate source-admission and Renderer-quarantine receipts. The manifest is
the sole input to a later atomic assembler; Renderer must not infer paths,
select a newer packet, or discover files by directory scan.

This proposal is not shared authority. The accompanying harness uses synthetic
fixtures only and emits a non-shipping ledger.

## Closed shape

The Integration-owned manifest has these exact top-level fields:

- `schemaVersion`: `1`;
- `disposition`: `integration_assembly_input_admitted`;
- `acceptedL3Baseline`;
- `directions`: exactly North, East, South, and West once each;
- `runtimeActivated`: `false`;
- `shippingResourcesMutated`: `false`; and
- `productionSelected`: `false`.

`acceptedL3Baseline` binds the exact accepted Renderer/product baseline by:

- `commit`: 40-character lowercase Git identity;
- `catalog`: repository-relative path plus SHA-256; and
- `industrialL3Manifest`: repository-relative path plus SHA-256.

Each direction entry binds:

- `direction`;
- the exact worker `packet` path plus SHA-256;
- the exact Integration `sourceAdmission` path plus SHA-256;
- the exact Renderer `quarantineReceipt` path plus SHA-256; and
- six direction-local byte locators, each with repository-relative path plus
  SHA-256: `raw`, `provenance`, `normalization`, `descriptor`, `contact`, and
  `review`.

All paths must resolve beneath the claimed repository root. Unknown fields,
absolute paths, traversal, missing bytes, hash drift, duplicate directions,
duplicate locator path/hash pairs, packet/admission/receipt disagreement,
fallback, alias, transform-equivalence, or registration drift fail closed.
The assembler reopens every packet/admission pair through the accepted v2
direction harness, verifies the retained quarantine receipt bytes against the
receipt regenerated from that pair, and invokes the existing exact 4/4 join.

## Output boundary

A successful read emits a deterministic
`atomic-admission-ledger-v1` containing:

- the exact input-manifest SHA-256 and accepted L3 baseline bindings;
- ordered North/East/South/West packet, admission, receipt, source, three-LOD,
  D4, and locator identities;
- `lodIdentityCount = 12` and `d4IdentityCount = 32`;
- `disposition = ready_for_atomic_assembly_nonshipping`; and
- `runtimeActivated = false`, `shippingResourcesMutated = false`, and
  `productionSelected = false`.

The ledger is an intake receipt, not source, shipping, staging, QA, or
production authority. Atlas packing, runtime lookup, Package.swift resources,
the shipping manifest, candidate staging, and PLAY-075 remain separately
authorized serialized work.

## Integration decision needed

Integration must decide and publish:

1. the canonical schema/document path and SHA-256 for
   `assembly-input-manifest-v1`;
2. the exact accepted L3 baseline commit plus catalog/manifest byte bindings;
3. the four exact Integration-admitted packet/admission and
   Renderer-quarantine receipt bindings; and
4. the later candidate-only resource path authorized to consume the resulting
   non-shipping ledger.

Until that decision is published, Renderer may run only the synthetic focused
harness and may not assemble or activate actual source bytes.
