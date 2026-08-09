# World Art Parallel Board — Contract-025 admission blocked

Snapshot: `2026-08-09T15:07:14Z` on Integration `master` at
`7e7598a79f21d65299982e55810a5017253d1c91`. This board is a truthful
status projection of the six governed cells; it grants no mutation authority.

| Cell | State / dispatch | Branch / claim | Head | Current boundary |
|---|---|---|---|---|
| North | `source_candidate` / blocked | `codex/citysim-world-art-north-imagegen` / PLAY-103 | `13a8cb9ffcd523ccac8fcdec136883e77f2df1b5` | candidate-only Frontier approve; South admission ledger and accepted 43-row digest are absent |
| East | `returned` / returned | `codex/citysim-world-art-east-imagegen` / PLAY-104 | `4d99575c2059d86218565481191a20795829665b` | V39 visual return: purple/magenta wedges remain in all 129 LODs; no repair route is granted |
| South | `predesign` / blocked | `master` / PLAY-106 status-only | `7e7598a79f21d65299982e55810a5017253d1c91` | local raw coverage is 43/43, but Integration admission is 0/43 and 172/516 authored/LOD outputs are absent |
| West | `returned` / returned | `codex/citysim-world-art-west-imagegen` / PLAY-105 | `732101725b5c1eb3e48f046e734e683306a588ea` | two-failure chroma stop; preserve rejected descendants and do not attempt a third repair |
| Renderer | `intake_preparing` / blocked | `codex/citysim-world-rendering-single-angle` / PLAY-101 | `1dbad1fdbbcb08125b3438070dcad0f7f6d3e850` | synthetic intake only; runtime selector false, no admitted renderer candidate or manifest |
| QA | `preregistering` / blocked | `codex/citysim-playtest-single-angle` / PLAY-102 | `f2721cb59137cbd61ba55cc1427fa58ff7efaa98` | candidate-neutral, observed values UNMEASURED, no app launch or candidate receipt |

Parallelism is intentionally zero: `requiredConcurrentCells=0` and no
mutation job is eligible. Every row carries an explicit resumption event;
there is no active overlap to report. The aggregate gate remains
`43 identities × 4 authored views × 3 LODs = 172/516`, with
`integrationAdmitted=0`, no common accepted-master/non-alias digest, no
PLAY-096 aggregate semantic validator binding, and no renderer/runtime or
production mutation permitted.

The next lawful Integration event is a fresh exact 43-row South admission
ledger/receipt with per-identity raw path+SHA, a non-alias accepted digest,
PLAY-096 schema and semantic-validator bindings, and current family route/head
acknowledgements. Only after that can a new renderer implementation claim and
candidate-bound QA route be issued. PLAY-089 observer activity is separate
from these six cells and does not create source or runtime authority.
