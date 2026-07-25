# PLAY-027 residential L1 variant-zero source attempts v01

**Authority:** `e8ebc12`

**Date:** July 24, 2026

**Disposition:** residential family frozen; no accepted directional source

## Retained inventory

| View | Raw SHA-256 | Normalized | Disposition |
|---|---|---|---|
| north | `f68c574334c09758cf919391d7c43323cc02a026dd4126b7f69345436a1c8fbc` | not run | Rejected: near-front elevation, no authoritative diamond/socket registration, gradient chroma field and broad background shadow. Directional-drift failure 1. |
| east | `0f28eb2c53e941181ca1615956516d12afeb17487ea98291486d727c36130315` | city `748b901a49dbe8a6cc89cb6887a643ffe8fc7d0a5e91806e003def5eaeabc681`; neighborhood `9aacbe062061e500371d1d4de1d1d4eff4234fcaee95e5131f98074f9ae608d2`; block `55c79dd0de2c2149789cf996a4cf14528e2a2d3153e75512b5e3442443e36394` | Rejected: block cleanup retained 97 hidden-RGB and 317 magenta-spill pixels; no complete set. |
| south | `b3a3ce2dd5647ac98d62549ca741ce04d7536b11d44410a345a2be81a6585ae0` | not run | Rejected: near-front elevation, no authoritative diamond/socket registration, gradient chroma field and broad background shadow. Directional-drift failure 2. |
| west | none | not run | Deliberately not generated after the second directional-drift failure. |

All three calls used the built-in ImageGen tool, the same frozen style,
registration and residential family hashes, and one complete retained prompt
per source. No rejected attempt is eligible as a sibling reference.

## Deterministic east cleanup

The existing repository
`GeneratedV4/tools/normalize_calibration_asset.py` ran against the east raw
source into the task-owned non-shipping PLAY-027 directory. It produced RGBA
city, neighborhood and block exports at the declared source-pixel budgets and
registered the pivot at 768 x 896.

The block export has:

- opaque bounding box `(379, 261, 645, 600)`;
- padding `(379, 261, 379, 83)`;
- four transparent corners;
- 97 transparent pixels with nonzero hidden RGB;
- 317 nontransparent pixels matching the magenta-spill predicate.

Normalization success is not source acceptance. The alpha/chroma findings
reject this attempt before a contact sheet.

## Mandatory family freeze

North and south are two consecutive directional-drift failures in the
residential family. Per CONTRACT-010 and the world-art skill, the family is now
frozen. No west call, prompt retry, or rejected-sibling reference is allowed.

The next authorized work is a task-owned template/anchor repair that makes the
four separate 2:1 orientations and named frontage sockets visually
unambiguous. The repaired inputs must receive new hashes and source revisions
before ImageGen resumes.

No renderer, atlas, production selection, shared manifest, PLAY-024 artifact,
gameplay, simulation, UI, save, package or build surface changed.
