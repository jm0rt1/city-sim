# PLAY-075 R1 identity ledger

## Governed lane

- Worktree:
  `/Users/James/.codex/worktrees/71b0/city-sim`
- Branch: `codex/citysim-playtest-quality`
- Published authority synchronized normally:
  `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`
- Authority merge checkpoint:
  `52dad3aaa2e60fccebec87429bda35fff5770330`
- Exact renderer candidate:
  `d41c2c68d5584c990e271af06c0b93ab50722f5e`
- Candidate merge-base with published authority:
  `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`
- `git merge-base --is-ancestor 10c2ed8 d41c2c68`: exit `0`
- Shipping product ancestor:
  `c032c4f2e7f73a339ec4d1b1898cc2ece1f746d7`
- `git diff --quiet c032c4f..d41c2c68 -- Native/CitySimNative/Sources/CitySimNative Native/CitySimNative/Package.swift script/build_and_run.sh`:
  exit `0`

The commits after `c032c4f` are evidence/validator retention only; the staged
product under review is unchanged through exact candidate `d41c2c68`.

## Candidate staged app

- Isolated clone:
  `/private/tmp/citysim-play075-r1-d41c2c6-build`
- Clone branch: `codex/citysim-playtest-quality`
- Clone HEAD: `d41c2c68d5584c990e271af06c0b93ab50722f5e`
- Candidate ID: `playtest-quality-w88bd7cb407a2`
- Bundle/defaults:
  `com.jfmortensen.citysim.playtest-quality.w88bd7cb407a2`
- Data root:
  `/private/tmp/citysim-play075-r1-d41c2c6-build/dist/test-data/playtest-quality-w88bd7cb407a2`
- App:
  `/private/tmp/citysim-play075-r1-d41c2c6-build/dist/CitySim-playtest-quality-w88bd7cb407a2.app`
- Executable SHA-256:
  `884565380daa705467e45deca29d67c64adee2c569f01635d36575465e3b21b9`
- Final staging-manifest SHA-256:
  `cd284cd2a581cffc9a971841bff9d3c6d224cae9f10de10b749cb0b36a4d5169`
- Source/staged generated-v4 manifest SHA-256:
  `1f4e9961ecb8ade54d2bb169721d11ca337e2f61053c72078a5e6bf71d59480b`
- Regular PID: `11931`
- Exact 900 x 600 / Reduce Motion PID: `18946`
- Both PIDs were bound to
  `CitySimNative-w88bd7cb407a2` and terminated with `SIGTERM`.

## Exact pre-R1 staged app

- Isolated clone:
  `/private/tmp/citysim-play075-r1-10c2ed8-baseline-build`
- Clone branch: `codex/citysim-playtest-quality-baseline`
- Clone HEAD: `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`
- Candidate ID: `playtest-quality-baseline-wc87e837fe84d`
- Bundle/defaults:
  `com.jfmortensen.citysim.playtest-quality-baseline.wc87e837fe84d`
- Executable SHA-256:
  `6e33759e75fcc948278c2233dd2204927bc9c2e5c3a496de68eab48f46e8231d`
- Final staging-manifest SHA-256:
  `14ff78667b174ecd5f713dcb5e485127d964ce14f9401d567648c4f3a053d818`
- Packaged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Industrial L2 manifest identity count: `0`
- Regular PID: `19404`
- Exact 900 x 600 PID: `23548`
- Both PIDs were bound to
  `CitySimNative-wc87e837fe84d` and terminated with `SIGTERM`.

The two staged apps used different app bundles, executables, bundle/defaults
domains, data roots, worktree tokens, manifests, and PIDs. A final process scan
found no matching candidate or baseline executable.
