# Validation

- Integration-root selected route validation: **PASS** for
  `quality-v1:play-075-r4-b-e4f038f9-final-qa`.
- Route receipt SHA-256: **PASS** — `23a0ff48...eecb`.
- Canonical route SHA-256: **PASS** — `2cb8b83a...a233`.
- Candidate receipt SHA-256: **PASS** — `a198cb63...9258`.
- Exclusive lease SHA-256: **PASS** — `95387e76...b533`.
- QA branch/HEAD/tree before evidence: **PASS** —
  `codex/citysim-playtest-quality`, `e72be9cb...ce7`,
  `361197db...e8f`; clean.
- Candidate source/tree before and after: **PASS** — `e4f038f9...54d4` /
  `26a21330...e56`; source worktree clean.
- Candidate ancestry: **PASS**; candidate is an ancestor of QA carrier.
- Product identity: **PASS**; `git diff e4f038f9..e72be9cb --
  Native/CitySimNative` is empty.
- Executable SHA-256 before and after: **PASS** — `228b233f...87db`.
- Manifest SHA-256 before and after: **PASS** — `0e31cea7...4118`.
- Resource inventory before and after: **PASS** — 82 files,
  `5ac8090b...e063`.
- Output root absent before launch: **PASS**.
- Matching candidate processes before launch: **0**.
- Candidate starts: **1 of 1**.
- Exact candidate PID: **2976**.
- Resource sample: RSS 250,784 KiB; CPU 0.9%; elapsed 16:56.
- Matching candidate processes after `SIGTERM 2976`: **0**.
- Regular captures: 1229x768 decorated; City, Neighborhood, Block.
- Compact captures: exact 900x600 app content; 904x652 decorated Computer
  Use envelope; City, Neighborhood, Block.
- Full Swift suite/build rerun: **NONE**.
- Product/source/shared-authority mutation: **NONE**.
- Final disposition: **RETURN** — terrain automatic return resolved; adjacent
  orange-building repetition automatic return unresolved.

## Capture SHA-256

| Capture | SHA-256 |
|---|---|
| `live/regular/lod-city.png` | `77c0003360ea3514010eb7d7b83affc55cf31691c23b7535649895df28ed11e8` |
| `live/regular/lod-neighborhood.png` | `04aec58e74cec1197bbcd8776f1e1dda2dd32fd44d5d54120bf6c51b2b941787` |
| `live/regular/lod-block.png` | `464843a9a67113478498ca7bf54a11aa1a2d9e1e1fe8bccaaf21e0e14e234a21` |
| `live/compact/lod-city.png` | `9fc0854228e6c552bfe2bc1ec43c80411facea58100461f77e2cc67c5caf9d2f` |
| `live/compact/lod-neighborhood.png` | `123f6ff989c775831ba8bc0a7a6cbfa6785c95671ea0abef47156c7e533b26e2` |
| `live/compact/lod-block.png` | `778b0d31d94c01afc0ef3ae572b7aa0abba7ca94f1366dc32b23976673829baf` |
| `live/interaction/pointer-road-placement.png` | `4cacd4e47cccfba7ed6589219dedaea3b6b16bd6597f7d354aeaca375c5ba53e` |
