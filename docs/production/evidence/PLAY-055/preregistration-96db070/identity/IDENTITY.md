# PLAY-055 Baseline Identity

## Git and stage

- Branch: `codex/citysim-playtest-quality`
- Published authority: `96db07032e548448f659b573381b6b5abbd94eb2`
- History-preserving merge: `56d099714d90c63c76993dcbd23eca9f6d615c54`
- Prior quality head preserved:
  `4e88d359fc0b6ac7b4e5a2838583c1081613e71b`
- Product/script diff from authority to staged source: empty
- Staging command: `./script/build_and_run.sh --stage-only`
- Stage result: passed; Swift build completed in 1.22 seconds

The exact staging manifest is retained as `staged-candidate.manifest`.

## Hashes

| Surface | SHA-256 |
|---|---|
| Staging manifest | `968170a07fd61c2921c289ba1423242a8d1dcddb0c06f2602922a5d73c478e3a` |
| Executable | `2b86a22674883efeacaa4b0f5b2acb91b6ae22281d6144e135d133a9d3df60e9` |
| Info.plist | `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe` |
| Atlas manifest, source and staged | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| Generated-v4 manifest, source and staged | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |
| City page zero, source and staged | `21d05fe9eb6c4b11ddf1772295960e61da67adaa069014116a812c3320b4822e` |
| Neighborhood page zero, source and staged | `8d2094b3047c35e59212aa93557da176bc1c20dcef3035a4fb0c022e851d29c2` |
| Block page zero, source and staged | `294722acd6265c6e48cfba8d542feeb42bda9fdd17f7f0ca16bbb734eca7e237` |

## Live routes

| Route | PID | Explicit process environment | Captured state |
|---|---:|---|---|
| Regular baseline | `97511` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play055-96db070/regular`; `CITYSIM_REGULAR_WINDOW=1` | Day 33 paused, City, no selection, `0` |
| Residential levels | `1499` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play055-96db070/residential-levels`; `CITYSIM_REGULAR_WINDOW=1` | Day 17 paused, L4 `(9,11)`, L1 `(10,11)`, `0` |
| Compact baseline | `2081` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play055-96db070/compact`; `CITYSIM_COMPACT_WINDOW=1` | Day 33 paused, City, no selection, `0` |
| Regular RSS | `4696` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play055-96db070/regular-rss`; `CITYSIM_REGULAR_WINDOW=1` | Day 33 paused, City, no selection, `0` |

Each route had exactly one process at the staged executable path. Computer Use
targeted that exact bundle. Every PID above was terminated with SIGTERM after
its bounded duty; the final exact-path process check returned no live product
process. Other owners' processes were untouched.

## Window and capture identity

- Regular request: `ProofWindowConfigurator.regularProofContentSize`,
  1278×768; original Computer Use files are 1278×768.
- Compact request: exact 900×600 content; original decorated Computer Use
  files are 900×652, including 52 pixels of window chrome.
- Captures are uncropped and unscaled.

The baseline comparison must use these explicit modes rather than inherited
window preferences. Candidate captures must repeat the same process and
record original dimensions.

## RSS

- Regular Day-33 settled route: `253,888 KiB` = `247.94 MiB`.
- Compact Day-33 settled Journal route: `144,320 KiB` = `140.94 MiB`.

These are preregistration observations, not replacement performance budgets.
The final candidate must repeat the same method plus three complete
city/neighborhood/block cycles and show no continuing high-water growth.
