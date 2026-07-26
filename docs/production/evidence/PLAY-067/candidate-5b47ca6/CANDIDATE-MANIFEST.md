# PLAY-067 Candidate Manifest

- Product commit:
  `5b47ca6a3ca10ba51c20f94b0b38d203b3ffbaa8`
- Published base:
  `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- Branch: `codex/citysim-ui-input`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Staged bundle:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Staged executable:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- Executable SHA-256:
  `7faa948305c993bf117f35b7b40e37e40346ce5e94a89398c9c467f658fd6924`
- Staging manifest SHA-256:
  `4831988350fda70133539ed84e06b97974d38eac534cfbf6bbebb5012ca8d521`

The regular binding used PID `61557` launched with
`CITYSIM_REGULAR_WINDOW=1`; its uncropped frames are 1278 x 768. The compact
binding used PID `64317` launched with `CITYSIM_COMPACT_WINDOW=1` and
`CITYSIM_REDUCE_MOTION_PROOF=1`; its uncropped frames are 900 x 652,
representing exact 900 x 600 content plus the 52-point titlebar. Process
environment was inspected before each binding capture. Both exact processes
were terminated after proof.

All binding frames use the same isolated quicksave: Day 6, paused, treasury
`$31,554`, net `-$82 / cycle`, five notices with warning highest severity,
objective `Balance the Books`, priority `Choose a growth engine`, Inspect
mode, and selected Road block 13,12.

## Frame hashes

| Route | SHA-256 |
|---|---|
| Regular closed | `f6c05281f76f1be16c5ff526cbc34a7be1e6b1342ebcc24fa9a4d3dd107ce519` |
| Regular Details | `606ca0ff9ed35d3c483ef1b67cc92a57849264a55fbafa7fd747f4f2588d8420` |
| Regular Focus City | `cb79e722afa33fb7e90784c609a174de2fc971938a3c3996e83aac11ae3f87db` |
| Compact closed | `cdb872a0d2c636f11a252af5a5022635e026e4520c92df514a68e0e1584f02fa` |
| Compact Details | `d50f09e58b4f43e8f4ff80742ff80cf16d9df9d4c7baf190a7783bb7a6872999` |
| Compact Focus City | `9b5061cb17768e9e7bafaf557195264a536d5c0bb6543083c5d0625cc2827412` |

The initial nominal regular and compact captures inherited an unverified
900 x 600 process. They are retained only under `excluded/` and
`rejected/inherited-900x600-baseline/`; they are not binding evidence and are
not used for aperture or composition claims.
