# Preregistration and Source Review

Read this reference for candidate-neutral QA preparation and direction-local source review.

## Preregister before the candidate arrives

When Integration dispatches QA-ahead preparation, freeze the candidate-neutral
acceptance contract while implementation or art production continues:

- exact fixture identifier, version, state hash, and mature-city placement;
- exact camera state, zoom, rotation, focus, and any deterministic scene seed;
- regular and compact window dimensions and the required pointer, keyboard,
  accessibility, and reduced-motion variants;
- allowed fresh-player knowledge, critical journey, rubric, stop conditions,
  capture names, and evidence destinations;
- quantitative visual, interaction, performance, persistence, and accessibility
  thresholds that apply to the claimed player outcome.
- for UI, Renderer, WorldArt, or other visual-facing work, one immutable
  composed-screen contract with the accepted predecessor commit, exact fixture
  and camera, 1280x800 and true 900x600 layouts, minimum unobscured map
  fractions, at most one simultaneous contextual guidance layer, and the
  candidate asset-profile target.

Commit the preregistration as its own QA checkpoint before inspecting the final
candidate. It may be exercised against the accepted baseline to prove that the
fixture and harness work, but that rehearsal is not candidate evidence. Do not
encode author hints, hidden shortcuts, expected control locations, or
candidate-specific coaching into the journey. If the candidate legitimately
changes a preregistered contract, preserve the original record and obtain an
Integration-approved revision before testing; never silently relax the rubric
after seeing a result.
Retain the baseline captures and hashes as comparison inputs. They are not
candidate evidence, but candidate acceptance cannot pass without comparing the
same fixture/camera/layout against those frozen predecessor artifacts.

Preregistration is complete only when the fixture materializer,
camera/capture coordinates, regular/compact variants, rubric, stop conditions,
and evidence destinations have been exercised against the accepted baseline
or fail closed with a named blocker. Baseline rehearsal is harness proof only.

Before reporting `preregistered`, write one task-owned machine-readable
preregistration packet bound to the exact family batch. It must include task
and claim path/hash, batch ID, published base, family-contract path/hash,
expected North/East/South/West logical keys, Integration ledger path/revision,
Renderer intake-plan path/hash, fixture/version/state hash, camera-state hash,
rubric hash, exact evidence root, and `rendererCandidateReceipt: null`.
The packet may report only `preregistered` or a fail-closed `blocked` state.
Integration must acknowledge that exact packet before counting QA as an active
or completed family row; a generic, prior-family, or unbound preregistration
never satisfies the current batch.

For a directional art family, preregister one family-level staged-app gate.
North, East, South, and West cells retain their own source determinism and
geometry evidence, but they do not request separate production acceptance from
QA. QA evaluates only the atomic renderer candidate containing all four exact
accepted directions and returns its disposition to Integration. A returned
direction may continue independently without
invalidating successful sibling source evidence; the final app journey remains
blocked until the renderer presents a complete 4/4 family.

Before 4/4 assembly, fresh QA may perform direction-local, candidate-neutral
literal-scale source review in parallel with Renderer technical review. That
review may recommend `pass` or `return` for Integration's direction-local
source admission, but QA must not write `integration_admitted` into the shared ledger
or the worker packet. It is not staged-app evidence, renderer ingestion,
production acceptance, or permission to activate a partial family. A failed
direction returns independently; successful sibling review evidence remains
valid when bound to unchanged exact packets and source commits.

Run simultaneous direction-local source reviews only through read-only
reviewers or disjoint temporary/evidence roots. One QA assembler owns the
claimed evidence packet and commit, preventing concurrent writers from
changing the acceptance record. Parallel source review never overlaps the
single final exact-candidate staged-app journey.
