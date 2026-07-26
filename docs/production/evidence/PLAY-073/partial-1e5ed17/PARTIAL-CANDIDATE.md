# PLAY-073 partial enabling candidate

## Disposition

This packet preserves a validated renderer improvement at product commit
`1e5ed17ac807daddbf71290c49e96c103c7a9223`.

It is **not PLAY-073 acceptance or completion**. PLAY-073 remains open and
visually rejected. Integration may evaluate this commit as a partial enabling
candidate alongside the authoritative density work in PLAY-076.

## Exact identity

- Branch: `codex/citysim-world-rendering`
- Rejected evidence ancestor: `b11391891d412c40741c8466c3e4bd5d6026ab1c`
- Product commit: `1e5ed17ac807daddbf71290c49e96c103c7a9223`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle ID: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Executable SHA-256:
  `a5cb79e37b5d518f43c870e4f07be5aca950bc950b9d9a0a8b6dc9b54c1ed70e`
- Staged candidate manifest SHA-256:
  `eabc7561cde4adcc4933274ee881589165614a4c5faf7669a0f3346563be974d`
- Packaged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Packaged world atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`

`candidate.manifest` is the exact verifier-produced identity manifest. The
verifier-launched PID recorded inside it was terminated after verification.
No exact candidate process survived evidence capture.

## Material improvements preserved

- The accepted authored road surface, lane, crossing, and wear cadence is
  visible again; the loop no longer reads as a flat light-gray vector ribbon.
- City Hall has the stronger civic focal hierarchy.
- The water tower presentation is restrained without altering its coordinate,
  frontage, pivot, hit truth, or accepted source bytes.
- Terrain and public-realm variation is stronger.
- The utility anchors and their real road access are joined by a deterministic,
  action-neutral renderer-owned ground component.
- Empty bridge coordinate `(14,13)` remains empty and buildable.
- Ambient ground construction is cached by truthful layout/detail identity,
  while authoritative activity candidates continue to be selected from every
  current snapshot.

## Binding remaining rejects

- The park's opaque source diamond remains unmistakable.
- Power, Water, and Industrial source-level pads still conflict even with the
  connected ground treatment.
- The adjacent repeated building silhouettes remain visible.
- Seven authoritative structures still sit within a broad green visual mass,
  so the opening reads as a starter board rather than a populated town.

Renderer-only polish cannot truthfully remove those boundaries. The required
cross-lane inputs are:

1. PLAY-076 authoritative 12-place opening truth.
2. Future independently accepted park, utility, and service source-art
   replacements with compatible projection, material, shadow, and grounding.

No renderer-invented building, road, occupied parcel, gameplay action, or
simulation truth was added.

## Validation

- Focused renderer suite: `64/64` passed.
- Full native suite: `254/254` passed.
- Focused cold profile:
  - backdrop `0.331 ms`
  - preparation `0.009 ms`
  - tile build `4.130 ms`
  - tree metrics `0.253 ms`
  - world update `4.470 ms`
  - total render `7.297 ms`
  - asset decode loads `0`
- Full-suite render diagnostic:
  - ten-pulse average `2.011 ms`
  - initial nodes `1695`
  - final nodes `1701`
- Focused visible-tree diagnostic:
  - nodes `985`
  - drawables `499`
  - actions `0`
- Residency:
  - resident textures `3`
  - resident/high-water bytes `41,943,040`
  - fallbacks `0`
- Thirty-minute-equivalent unchanged-pulse soak:
  - pulses `4286`
  - average `0.0006 ms`
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed against the exact product commit.
- `git diff --check`: passed before the product commit.

## Exact Day 11 live proof

The exact staged executable loaded the isolated quicksave with:

- state digest:
  `f9d36899ff9479c3b40e3f2af0194f81c78e998ac37d0c10454c8375015caf21`
- tick `40`, Day `11`, paused
- treasury `$31,114`
- residents `310`
- happiness `63%`
- jobs filled `190`
- utilities `100%`
- City layer, Inspect mode, no selected block

The transient load toast was allowed to clear. The map then received the real
keyboard `0` framing command before capture.

- `live/regular-day11-unselected.jpeg`: uncropped `1278x768` decorated window.
- `live/compact-day11-unselected-decorated.jpeg`: uncropped `900x652`
  decorated window.
- `live/compact-day11-unselected-content-900x600.jpeg`: exact `900x600`
  content crop from the retained decorated compact frame.
- `ax/compact-day11-unselected.txt`: full compact accessibility tree bound to
  the same settled frame.

The evidence records the material improvement and the source/state boundary;
it does not claim that the visual rejection has been cleared.
