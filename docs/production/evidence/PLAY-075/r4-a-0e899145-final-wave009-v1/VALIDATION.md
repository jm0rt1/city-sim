# Validation

- Selected route validation: **PASS** for
  `quality-v1:play-075-r4-a-0e899145-final-qa`.
- QA branch/HEAD at admission: **PASS** —
  `codex/citysim-playtest-quality` at
  `bc9b82aa5992bef401dec419591b307171c84d84`.
- Carrier receipt SHA-256: **PASS** — `28d166ab...977b5b`.
- Canonical route SHA-256: **PASS** — `8d3b08c2...8904bf`.
- Candidate receipt SHA-256: **PASS** — `d2b7a906...07e2c6`.
- Exclusive lease SHA-256: **PASS** — `377d24be...db70e`.
- Candidate source/tree before and after: **PASS** — `0e899145...b7331` /
  `e368d22c...37a95`; source worktree clean.
- Executable SHA-256 before and after: **PASS** — `83641837...ec7`.
- Manifest SHA-256 before and after: **PASS** — `b3127b04...f4d`.
- Resource inventory binding: **PASS** — 79 files,
  `7e5c22ea...c7ff4` from the immutable candidate receipt.
- Output root absent before launch: **PASS**.
- Matching candidate processes before launch: **0**.
- Candidate process starts: **1 of 1**.
- Exact candidate PID: **20602**.
- Matching candidate processes after `SIGTERM 20602`: **0**.
- Product/source/fixture/shared-authority mutation: **NONE**.
- Full Swift suite/build rerun: **NONE**; exact Integration record consumed as
  instructed (`325` executed, `3` expected skips, zero failures).
- Regular captures: **1278x768 decorated**, city/neighborhood/block.
- Compact route: **exact 900x600 app content**; uncropped Computer Use capture
  envelope `904x652`, city/neighborhood/block.
- Reduce Motion original preference restored: **PASS** (`off -> on -> off`).
- Exact restored selected-target fingerprint: **PASS** —
  `81416f6f3b30169d49631dc6ddf8f2889dbffeb9e46fa6f285f7528f87a835db`.
- Final disposition: **RETURN**, `18/20`, with two automatic-return conditions.

Key capture SHA-256 values:

| Capture | SHA-256 |
|---|---|
| `live/regular/lod-city.jpg` | `8a306122701598d3b255a07190917ac30828dc8bf1c9c444b836e50322d1ac99` |
| `live/regular/lod-neighborhood.jpg` | `0de7aa7b49f6bc7311b422fbf728600de9f9968dffde1fd8742ab5e052f4dc19` |
| `live/regular/lod-block.jpg` | `03221f5d69be719283cba5b66aca69b40aa3ff07021abf9817899c0d7246dd00` |
| `live/compact/lod-city.jpg` | `e287ff6479a41f11b920ff47a8ad1f1d788210d4682ea36eb6bd394ad07ac72e` |
| `live/compact/lod-neighborhood.jpg` | `409fe96961409e56f42fc86ab489955bfa53ea87c9fa8c8e5274918262fec46b` |
| `live/compact/lod-block.jpg` | `6b042cf7784f11c385d346c7db630fa86aacbdab4354f3166c2bf61c9eaa23d6` |
| `live/compact/reduce-motion.jpg` | `1420c8ff389ca9a4b07081e74e80234c468818372b6c3d1733c66ff635adc1a9` |
| `live/compact/pointer-selection.jpg` | `2cd9b9f079e73757d50e248233836a9b230c2a12adb7242b64cb3532f817b16b` |
| `live/compact/undo-restored-reselected.jpg` | `8a6a7bc4cf4b189397dc74e11f969d67d39f1c356487933a01ebd364d7eef52c` |

The packet is evidence-only and remains confined to the lease's exclusive
PLAY-075 output root.
