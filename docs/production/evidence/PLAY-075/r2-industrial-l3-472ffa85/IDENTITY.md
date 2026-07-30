# PLAY-075 Industrial L3 replacement R2 identity

## Candidate boundary

- Candidate under test:
  `472ffa85cd35639a675c1c2e4ede748c94446a7f`
- Isolated attached branch:
  `codex/citysim-playtest-quality-r2-472ffa85`
- Isolated worktree:
  `/private/tmp/citysim-play075-r2-472ffa85`
- Worktree token:
  `wa778da7360e3`
- Candidate ID:
  `playtest-quality-r2-472ffa85-wa778da7360e3`
- Bundle ID/defaults domain:
  `com.jfmortensen.citysim.playtest-quality-r2-472ffa85.wa778da7360e3`
- Candidate data root:
  `/private/tmp/citysim-play075-r2-472ffa85/dist/test-data/playtest-quality-r2-472ffa85-wa778da7360e3`

Later Integration and art-governance commits did not rebind this gate. No
result or score was transferred from `cc3112fe`, `de680509`, or an earlier R2
candidate.

## Staged identities

- Executable SHA-256:
  `bf0c30b1d62b83e47a39bc489f98f5290951186d298ed9a197d376bbe4604a6f`
- Staged atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`
- Source atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`
- Staged generated-v4 manifest SHA-256:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`
- Source generated-v4 manifest SHA-256:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`
- Fixture SHA-256:
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`
- Fixture state digest:
  `dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f`

The same executable and packaged resources were used for regular and compact
segments. No rebuild, restage, or nearby-SHA substitution occurred between
those segments.

## Process identity

| Segment | PID | Layout | Reduce Motion | Live RSS | Terminated |
|---|---:|---|---|---:|---|
| Regular | 26465 | 1278 x 768 content | System/default | Not sampled | Yes |
| Compact | 27925 | 900 x 600 content | Forced proof | 57,232 KiB | Yes |

The decorated compact screenshots are 900 x 652 pixels: 900 x 600 app content
plus 52 pixels of title/toolbar chrome.
