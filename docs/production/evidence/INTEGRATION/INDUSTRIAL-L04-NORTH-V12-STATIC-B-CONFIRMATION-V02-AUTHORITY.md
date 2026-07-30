# Industrial L4 North v12 static-B confirmation v02

**Owner:** Integration
**Task:** PLAY-027
**Branch:** `codex/citysim-world-art`
**Supersedes:** `INDUSTRIAL-L04-NORTH-V12-STATIC-B-CONFIRMATION-V01-AUTHORITY.md`
at SHA-256
`e06a790442763f99b21ea310caaadd8321a01ade196db4dbb3fbdf1621b507b0`

## Disposition of v01

The v01 worker merged its exact publication, detected a contradiction during
preflight, changed no files, started no DCC child, and returned clean at
`3e5d418b6c805f3a68410be93c77afb7e3d26194`.

V01 required byte identity for `INPUT-BINDINGS.json`, while also requiring a
new claim hash, contract, process ID, and output root. The frozen lowerer
correctly writes the active claim hash and complete contract hash into that
file, making the v01 gate impossible without prohibited rewriting. V02 repairs
only that comparison rule.

## Exact authority binding

- Current PLAY-027 claim SHA-256:
  `154abc8a6f2360421b4fa4a7367290342b78cc9f4e10b69e2bceafb547ee3a86`.
- Frozen accepted static-A `INPUT-BINDINGS.json` SHA-256:
  `ee3691ffc5a8a817d35913e4359a66f0efb12042ab505f1f95b2b2c9c7bd3e1c`.
- Frozen accepted static-A embedded contract SHA-256:
  `c3cf003c8c123d2fdcad1d2c04f4ae0f450b41ab80f4dcb4b5e056f6835df6e7`.
- Frozen accepted static-A embedded claim SHA-256:
  `83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d`.

The external dispatch must supply and verify the exact v02 publication commit,
this file's post-publication SHA-256, and the claim SHA above before mutation.

## Repaired A/B comparison

All v01 frozen inputs, owned paths, one-child lease, execution behavior,
monitoring, failure inventory, acceptance counts, registration threshold, and
hard stops remain binding.

Static B must be byte-identical to accepted static A for exactly these five
run-neutral files:

1. `BLENDER-OBJECT-MANIFEST.json`
2. `MATERIAL-MANIFEST.json`
3. `PROJECTION.json`
4. `TOPOLOGY.json`
5. `VALIDATION.json`

`INPUT-BINDINGS.json` must have exactly the same schema, key set, array order,
and values as accepted static A after applying only these two expected
substitutions:

| JSON pointer | Accepted static A | Required static B |
|---|---|---|
| `/bindings/claim/sha256` | `83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d` | `154abc8a6f2360421b4fa4a7367290342b78cc9f4e10b69e2bceafb547ee3a86` |
| `/contractSHA256` | `c3cf003c8c123d2fdcad1d2c04f4ae0f450b41ab80f4dcb4b5e056f6835df6e7` | exact SHA-256 of the committed static-B v02 execution contract |

No other field, key, type, array order, or value may differ. The prelaunch
receipt must freeze the committed static-B contract hash and prove a strict
recursive comparison with this two-pointer allowlist. The final A/B receipt
must repeat that comparison against the child-produced file.

`PROCESS-PROVENANCE.json` remains excluded from byte identity and must retain
its complete process-bound facts.

## Execution lease and hard stop

- Global DCC cap: one.
- Slot: `dcc-1`.
- Attempt: `industrial-l04-north-v12-static-b-confirmation-v02`.
- Process: `static-b`.
- Maximum child starts: one.

A child start consumes the lease. On failure, retain only the immutable partial
child subset plus one exclusive `FAILURE.json`, commit, and stop. On success,
commit the exact five-file identity and two-pointer INPUT-BINDINGS comparison,
process provenance, validation, and handoff, then stop clean.

No retry, render invocation, pixel, `.blend`, normalization, Process A/B/C,
appearance lock, sibling DCC, source admission, Renderer quarantine, runtime
activation, shipping mutation, push, or self-acceptance is authorized.
