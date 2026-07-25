# PLAY-053 Completion — Independent World and HUD Excellence Gate

- **Lane:** Playtest quality
- **Branch:** `codex/citysim-playtest-quality`
- **Status:** ready-for-integration / independently approved
- **Exact product candidate:** `ad2f35314bb471a07923c41653374b05ace51ee3`
- **Evidence commit:** `2e83570eda92e14fcf39bca78b9152ff3c7b8411`
- **Preserved prior rejection:** `6803f6146febd2c011ed1e8a1abd346a9825837b`
- **Independent score:** **19/20**

## Player-visible outcome

The returned Wave 006 candidate passes the preregistered world-excellence gate.
At explicit regular and exact 900 x 600 compact sizes, the deterministic
industrial-complication city is materially preferable to the retained 14/20
candidate in both the ordinary city/readability comparison and the
pollution/consequence comparison. Composition and
projection/material/light/street coherence each score 4/4, no category scores
below 3, and no automatic reject is present.

The exact score is:

- composition and map occupancy: 4/4;
- projection, material, light, and street coherence: 4/4;
- useful LOD, depth, variety, and district life: 3/4;
- state, consequence, and interaction clarity: 4/4; and
- shipping credibility, HUD, accessibility, and performance: 4/4.

The remaining point reflects narrow building-family and directional variety.
It is disclosed future world-art work, not a blocker for this exact compatible
candidate.

## Exact identity and proof

The independent packet is:
`docs/production/evidence/PLAY-053/rescore-ad2f353/`.

Primary records:

- `docs/production/evidence/PLAY-053/rescore-ad2f353/DISPOSITION.md`
- `docs/production/evidence/PLAY-053/rescore-ad2f353/WINDOW-AND-PROCESS-IDENTITY.md`
- `docs/production/evidence/PLAY-053/rescore-ad2f353/SHA256SUMS`
- `docs/production/evidence/PLAY-053/rescore-ad2f353/logs/world-asset-pack.json`
- `docs/production/evidence/PLAY-053/rescore-ad2f353/logs/production-geometry.json`
- `docs/production/evidence/PLAY-053/rescore-ad2f353/live/`

The exact staged identity was
`dist/CitySim-playtest-quality-wf967be0ab5b4.app`, bundle and preference
domain `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`, with:

- staging-manifest SHA-256
  `c85c3414b135fcc0394651e8495191fbfa34ed23f4e1576b0fe3abaa2c46abfc`;
- executable SHA-256
  `2b86a22674883efeacaa4b0f5b2acb91b6ae22281d6144e135d133a9d3df60e9`;
- frozen fixture SHA-256
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- fixture envelope digest
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`;
  and
- fixture spatial digest
  `41ef511b0613a33ae643e60b2a934a5a11edbf14a99a422d3f635c9f133fe7e5`.

Source and staged world-pack resources matched exactly, and the validator
reported zero fallback assets.

## Commands and exact results

- Governed exact stage-only build: passed in 1.93 seconds.
- `swift test --package-path Native/CitySimNative`: 201/201 passed, zero
  failures, 84.678 seconds.
- Focused returned-camera test: 1/1 passed, zero failures, 1.769 seconds.
  It printed exact default scale `0.312796950340271` / priority width
  `0.7473417931726477` and compact scale `0.576345682144165` / priority
  width `0.5796985019395197`.
- `WorldRenderingTests`: 43/43 passed, zero failures, 14.757 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `git diff --check`: passed.
- World-pack validation: 84 payload checks, 84 extrusion checks, 974 packed
  overlap checks, four pages, 133 inventory entries, exact source/staged
  parity, zero failures.
- Production-geometry validation: 324 reciprocal ground contacts, 36
  building/road setbacks, 256 entrance/prop exclusions, zero collisions and
  zero failures.

## Hands-on routes

All scored routes used the real staged app, the same byte-identical paused
tick-128 / Day-33 industrial-complication fixture, deterministic camera reset
`0`, and independent data roots:

- regular PID `43383`, explicit regular content proof;
- compact PID `45772`, exact 900 x 600 content;
- compact interaction PID `47951`, exact 900 x 600 content; and
- Reduce Motion PID `46235`, explicit regular content proof.

The live journey independently verified ordinary city and pollution
comparisons, city/neighborhood/block LODs, connected roads and ground contact,
selection, an occupied-placement rejection retained for more than four
seconds, valid pointer placement at `15,11`, keyboard Return placement,
Command-Z restoration, AX activation of the same coordinate exactly once,
Full Keyboard Access focus exit/restoration, construction truth, overlay
legend, and Reduce Motion information parity.

## Accessibility and compact consequences

Exact compact content remained unclipped and retained the active district,
selection, placement reason, map actions, pollution legend, and HUD aperture.
Pointer, keyboard Return, exposed AX action, and Full Keyboard Access all
addressed the same semantic map target. The pollution legend supplied named
and shaped Clean, Watch, and Polluted states, so color was not the only
carrier. Reduce Motion preserved the same authoritative state, AX semantics,
and consequence information.

## Performance and residency consequences

- Cold renderer: 3.749 ms world update, 4.973 ms total render, zero decode
  loads.
- Thirty-minute-equivalent unchanged-pulse soak: 0.0006 ms average, stable
  node identity, two bounded actions.
- Active-plus-adjacent residency: 10,485,760 bytes at city LOD and 33,554,432
  bytes at neighborhood/block LOD.
- Settled RSS: 126,320 KiB regular after 76 seconds; 213,984 KiB compact
  interaction after 84 seconds; 229,808 KiB Reduce Motion after 29 seconds.

All observed RSS values remained below the 333.8 MiB ceiling, with no
continuing high-water growth observed.

## Save and deterministic-state consequences

No save schema, persistence contract, or product source changed. Each isolated
route began from the same committed quicksave bytes and matching envelope and
spatial digests. The fixture loaded paused; successful build plus Undo restored
the visible and treasury state. The 201-test suite retained the broader
save/load coverage. This renderer-focused rescore did not repeat the earlier
release-level terminate/relaunch and backup-recovery journey.

## Limitations

- The first attempted default session inherited compact window sizing. It was
  detected before scoring, excluded, removed, and replaced by explicit regular
  and compact routes.
- Real-app regular proof uses the repository's 1,278 x 768 NSWindow content
  contract, while the deterministic camera fixture separately uses
  1,280 x 800. The evidence records both rather than conflating them.
- Category 3 remains 3/4 because authored building-family and directional-view
  breadth are visibly limited.
- The gate did not repeat the broader release save/relaunch/backup journey
  because no persistence surface changed.

## Process cleanup

Each scored PID was proven to be the sole process at the exact staged
executable path and was terminated explicitly after capture. Final inspection
found no process at that path. No other owner's process was terminated.

## Files changed and integration notes

Evidence commit `2e83570eda92e14fcf39bca78b9152ff3c7b8411` adds only the
candidate-bound PLAY-053 evidence packet. The following quality-management
commit adds only this completion record, updates the PLAY-053 claim, and
updates the PLAY-053 backlog status; its exact hash is reported in the lane
handoff because a commit cannot embed its own hash.

Integrate the ordered quality commits without rewriting:

1. `2e83570eda92e14fcf39bca78b9152ff3c7b8411` — independent evidence and
   19/20 disposition;
2. `PLAY-053: Complete independent excellence gate` — completion, claim, and
   PLAY-053 status management.

Candidate `ad2f35314bb471a07923c41653374b05ace51ee3` is independently
**APPROVED** and ready for integration review. The lane made no product,
fixture, build-script, package, shared-contract, or legacy Python change and
did not push or self-integrate.
