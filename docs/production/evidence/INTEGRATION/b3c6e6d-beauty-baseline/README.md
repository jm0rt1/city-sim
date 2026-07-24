# Accepted Beauty Baseline — Integration Proof

- **Exact master:** `b3c6e6d8c4efb6619790ef1bd49c68c2816a4d0b`
- **Integration merge:** `37894a6`
- **Independent quality disposition:** `52ea60b`
- **Staged identity:** `master`
- **Bundle identifier:** `com.jfmortensen.citysim`
- **Executable SHA-256:** `ce57495d32edbcf02fa3cc9e219b32c629d2e40de0aac9c6f91cdbe2ef598e00`
- **Manifest SHA-256:** `38b647b125ba6f2ea862279ea656fba2d83d548d949fa6b4370e3dd1c4834e84`
- **Generated-v4 manifest SHA-256:** `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`
- **Exact compact PID:** `80467`

## Integration validation

- Full post-merge native suite: 185/185 passed.
- `git diff --check`: passed before evidence retention.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- Exact `./script/build_and_run.sh --verify`: passed at default and with
  `CITYSIM_COMPACT_WINDOW=1`.
- The default staged app exposed the generated-v4 connected district, authored
  termini, bounded pedestrians and vegetation, three-dimensional buildings,
  command deck, city status, and semantic City map.
- Build mode retained one announced selected coordinate. An occupied Road at
  block 13,10 showed a grounded red Residential preview, the same unavailable
  AX reason, no mutation, and durable recovery guidance.
- Exact compact retained a dominant interactive map, full city status,
  Objectives, command-center controls, semantic City map, and keyboard focus.
- Opening and closing command-center details returned focus to the City map
  through Escape without changing simulation or spatial state.

## Retained frames

- `compact-world.jpeg` — exact 900 x 600 content, generated-v4 city and compact
  HUD.
- `compact-escape-restored.jpeg` — exact compact map after command-center
  dismissal and focus restoration.

The independent combined candidate evidence remains under
`docs/production/evidence/PLAY-052/combined-704784b/` with 28 additional
candidate-bound frames, AX trees, process identity, and the 17/20 visual score.
