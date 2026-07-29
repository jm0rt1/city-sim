# Industrial L4 source-arrival gate preparation authority

- **Published baseline:** `b8a779ad2a25e60aec1b9c6f765027b2ad904db2`
- **Renderer claim:** `PLAY-073`
- **QA claim:** `PLAY-075`
- **Disposition:** `AUTHORIZED_NON_SHIPPING_ARRIVAL_PREPARATION`

North process A is active under its narrow appearance-calibration authority.
No Industrial L4 source is accepted yet. This authority removes two
contract-independent delays before accepted N/E/S/W packets arrive; it does
not bypass the North appearance lock or authorize art acceptance.

## Renderer preparation

The renderer may add one file-backed, non-shipping direction-packet intake
harness under its existing PLAY-073 tests and
`docs/production/evidence/PLAY-073/industrial-l04-direction-quarantine-v1/`
root. The harness must:

- load one exact JSON packet from a caller-supplied path rather than only
  constructing synthetic Swift values;
- validate it through the already accepted bridge-bound packet decoder and
  quarantine rules;
- emit a deterministic task-owned receipt naming packet path/hash, decoded
  identity, direction, exact bridge/appearance-lock identities, validation
  result, and zero shipping/runtime mutation;
- reject schema drift, missing or stale bridge/appearance authority,
  aliases/transforms/fallback, registration/frontage drift, production
  selection, and any input outside the claimed packet path;
- preserve the accepted 0–4 non-activating state matrix.

Renderer may also make the preserved `5d814794` semantic-slot/camera intake
fixture baseline-neutral by comparing manifest/catalog state before and after
instead of requiring a particular accepted Industrial maximum level. It must
not adopt any R2 product, resource, atlas, manifest, runtime mapping, staged
fixture, package, or shipping mutation.

Required handoff: exact focused command, file-backed valid and rejection
fixtures, deterministic repeated receipt, changed-file inventory, and clean
candidate commit. Do not run the full Swift suite or staged app for this
preparation.

## QA preparation

PLAY-075 may add one candidate-neutral deterministic fixture-materialization
tool and receipt format wholly under
`docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/`.
It must:

- bind the existing immutable L3 mature-city fixture SHA
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`;
- accept an explicit exact renderer candidate identity plus exact N/E/S/W
  packet identities as inputs;
- refuse one through three directions, stale candidates, mutable defaults, DCC
  labels, per-direction transforms, and unbound packet hashes;
- deterministically describe the candidate-bound L4 completed,
  construction, and condition fixture derivatives and expected capture tree;
- write only to a caller-supplied task-owned output root and reproduce an
  identical receipt from identical inputs.

This is preparation only. It may not create an acceptance fixture for a
nonexistent renderer candidate, alter the frozen source fixture, run the
staged app, inspect product internals during the future journey, score the
rubric, or declare QA disposition.

## Still serialized

The following remain blocked: North appearance lock; World Art B/C and sibling
pixels; actual source admission; Industrial L3 R2 disposition; shipping
atlas/manifest/runtime assembly; staged candidate construction; final
independent QA; integration and production selection.
