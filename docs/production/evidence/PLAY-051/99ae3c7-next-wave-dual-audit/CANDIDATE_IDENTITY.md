# PLAY-051 integrated candidate identity

Audit date: 2026-07-21 EDT (runtime timestamps cross 2026-07-22 UTC)

- Product authority: `99ae3c7925825cfb8eccb47a678405c6e58d2a46` (`origin/master`)
- Quality build HEAD: `e9e429ce26244bd6571c1d2920b1a4e30c3e79a9`
- Branch: `codex/citysim-playtest-quality`
- Worktree token: `wf967be0ab5b4`
- Candidate ID: `playtest-quality-wf967be0ab5b4`
- Bundle ID / defaults domain: `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Staged bundle: `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- Executable: `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- Resource bundle: `dist/CitySim-playtest-quality-wf967be0ab5b4.app/CitySimNative_CitySimNative.bundle`
- Isolated data root: `dist/test-data/playtest-quality-wf967be0ab5b4`
- Candidate manifest: `dist/manifests/playtest-quality-wf967be0ab5b4.manifest`
- Manifest SHA-256: `bd00be2216af4b120a8f45b1424d671d003abcc5fecc2f92c2cd65c7d6352fd3`
- Executable SHA-256: `db5bc88ee6776d00baa94f4ee4894f8638fe2319d3c4d65894bdd0be34e38945`
- `Info.plist` SHA-256: `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`

## Process and viewport proof

- Default launch: manifest PID `70899`; the inspected process command resolved to the executable above. Default content viewport was `1440x900`.
- Compact launch: exact staged bundle launched with `CITYSIM_COMPACT_WINDOW=1` and the same injected data root. Inspected PID `73599` resolved to the executable above. The capture was `900x652` including 52 px of window chrome, proving a `900x600` content viewport.
- PID `73599` was terminated after the bounded audit. No unrelated process was touched.
- RSS observations: initial default launch `187,760 KiB`; settled default relaunch `82,912 KiB`; settled compact `79,696 KiB`; final compact `67,024 KiB` after 12:40 elapsed. No continuing high-water growth appeared in this bounded session, but this was not a soak test.

## Freshness and persistence identity

The first preflight exposed stale defaults and was discarded. Its frame is retained as `visuals/00-invalid-stale-defaults-preflight.png` and is not acceptance evidence. The defaults domain was deleted, the generated root was moved aside, and all scored interaction began at `visuals/01-default-welcome-fresh.png` with a new isolated root.

- Quicksave size: `132,813` bytes
- Quicksave SHA-256: `09ee8ba40bd684e59502fbd930de98f68b878ffd8bf95555418b179f6d969829`
- Save schema: `1`
- Saved digest: `9d97e2689279bc41b0645c772035ae9ebc9195a67cb7262026b86510e1da20e3`
