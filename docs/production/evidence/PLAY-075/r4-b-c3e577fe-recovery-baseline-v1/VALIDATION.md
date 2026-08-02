# Validation

- Integration-root selected-route validation: **PASS**.
- Route receipt SHA-256: **PASS** — `9ca90045...a59c0`.
- Canonical route SHA-256: **PASS** — `efd9c6f5...083fd`.
- PLAY-075 claim SHA-256: **PASS** — `5dd3aeef...0362`.
- QA branch/HEAD/tree before evidence: **PASS** —
  `codex/citysim-playtest-quality`, `2cdf7643...fa5`,
  `dd4d1677...76b`; clean.
- Candidate source commit/tree: **PASS** — `c3e577fe...9d81` /
  `1871b575...bee9`; source worktree clean.
- Candidate receipt SHA-256: **PASS** — `813c27e8...d7ab`.
- Exclusive lease SHA-256: **PASS** — `4f9a69c2...b4b9`.
- Output root absent before admission: **PASS**.
- Matching candidate applications before launch: **0**.
- Executable SHA-256: **PASS** — `1486ca40...f277`.
- Manifest SHA-256: **PASS** — `a103e31b...5458`.
- Info.plist SHA-256: **PASS** — `6ea1b67f...a8d7`.
- App inventory count: **PASS** — 82 files.
- App inventory SHA-256: **FAIL** — expected `eaa891eb...abcd4`,
  observed `dcd21373...c059`.
- Inventory-method control: **PASS** — the identical command reproduced the
  retained prior R4-B app receipt digest `5ac8090b...e063` exactly.
- Candidate launches: **0 of 1**; lease remains unconsumed.
- Screenshots, visual scoring, interaction journey: **NONE**.
- Full Swift suite/build rerun: **NONE**.
- Product/source/shared-authority mutation: **NONE**.
- Final disposition: **RETURN** at the prelaunch immutable-build identity gate.
