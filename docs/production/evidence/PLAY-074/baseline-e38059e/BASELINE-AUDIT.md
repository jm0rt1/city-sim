# PLAY-074 Build-Flow Baseline Audit

Date: 2026-07-25

This packet freezes the unmodified published authority before PLAY-074
product work. It records the starting build, rejection, and recovery
experience; it is not an acceptance result.

## Exact candidate

- Source: `e38059e721dae05c8df421754e3cb63ddf3fa153`
- Branch: `codex/citysim-ui-input`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged executable SHA-256:
  `ba2b8d50998f39dbef5c6ea037e7ea1e96b42481aff16bf75894c58cad6f2429`
- Staging manifest SHA-256:
  `baa827f8d06bbcfe13af5d629d70993517ae02f8aeb9c56ae22db661ef19e4ba`
- Compact staged PID: `33699`
- Compact launch environment:
  `CITYSIM_COMPACT_WINDOW=1 CITYSIM_REDUCE_MOTION_PROOF=1`

The manifest, bundle, executable, process, screenshots, and Computer Use
accessibility inspection all resolved to this lane candidate.

## Frozen same-state journey

The regular process was paused and saved, then the same quicksave bytes were
loaded into the isolated compact data root:

- Day 11, paused;
- treasury `$31,078`, net `-$102 / cycle`;
- objective `Balance the Books`;
- strategy priority `Choose a growth engine`;
- six notices, highest severity warning;
- Residential selected for placement.

The regular invalid target is occupied block `12, 12`. The compact invalid
target is open block `14, 16` without direct road access. Both exercise the
same store-owned placement presentation and durable rejection route while
covering two accepted simulation reasons.

## Original frames and measured aperture

| Frame | Pixels | Map top | Map bottom | Visible map height |
|---|---:|---:|---:|---:|
| `before-regular-invalid-target.jpeg` | `1278 × 768` | `183` | `646` | `463` |
| `before-compact-invalid-target.jpeg` | `900 × 652` | `163` | `579` | `416` |
| `before-compact-rejection.jpeg` | `900 × 652` | `163` | `579` | `416` |

The compact screenshot includes a 52-point titlebar above the exact
`900 × 600` content surface. Its closed build-mode aperture is therefore
`416 / 600 = 69.3%`.

## Reproduced gaps

The world preview truth is already strong: the exact target is selected and a
red invalid footprint is drawn on the map. The command surface does not yet
turn that truth into a legible decision:

- regular and compact show only a tiny `Block … / Blocked` summary;
- footprint, full cost, likely consequence, and explicit Escape cancellation
  are absent from the selected-target surface;
- the accepted disabled reason exists in AX and appears in a durable toast
  after Return, but is not visibly attached to the decision strip;
- there is no direct truthful recovery action from the selected blocked place;
- compact makes the blocked state visible but requires AX or a failed attempt
  to learn the reason.

The regular AX target was:

`Build Residential at block 12, 12 — Unavailable. Demolish the existing
structure before building here.`

The compact AX target was:

`Build Residential at block 14, 16 — Unavailable. This building needs direct
road access.`

Return reached the existing durable rejection path in both layouts without
clearing the tool or target. Compact announced:

`This building needs direct road access. Residential remains selected —
choose another block.`

## Frame SHA-256

- regular invalid target:
  `0cfd812f555f8ab4f5628e8b03d0bba0a1d6cb44d5c6be6d7af78be3fe879487`
- compact invalid target:
  `e48dec607bf22a2be4d8da08e9eb895d316deb0c7d719d450152bd845b7707dd`
- compact durable rejection:
  `4f4523e8c442398f299aea53f006386ddaa5c12dbb6cb68de8bc997a725ec86b`
