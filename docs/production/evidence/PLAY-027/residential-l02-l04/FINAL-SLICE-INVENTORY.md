# PLAY-027 Residential L2-L4 final slice inventory

**Disposition:** frozen review candidates only; none are accepted or production
selected.

| Level | Density story | N | E | S | W | Candidate commit |
|---|---|---|---|---|---|---|
| L2 | compact three-floor walk-up with corner stair articulation and cross-gabled roof | `source-v05` | `source-v05` | `source-v05` | `source-v05` | `ed06c8e` |
| L3 | five-floor stepped U/courtyard mid-rise with lower bridge | `source-v01` | `source-v01` | `source-v01` | `source-v01` | `50977b3` |
| L4 | seven-floor urban podium tower with setback wing and copper crown | `source-v01` | `source-v01` | `source-v01` | `source-v01` | `af4dd25` |

## Final raw pixel hashes

| Level | Direction | Revision | SHA-256 |
|---|---|---|---|
| L2 | N | `source-v05` | `c79c5e0906c2e2b3c25682d6f79824d4e0d52e3be1821ba62f69fc6139656f6e` |
| L2 | E | `source-v05` | `d985175f7e31681343108df3e5360b11ddeb56eab6d101316f9ffd1b39591609` |
| L2 | S | `source-v05` | `f0d7efcc05bbc9361cab8259daa9f8fd52f67f50baa1699217d9b41cbb714490` |
| L2 | W | `source-v05` | `3ecb2a3892283c4b012360aa2413a47e772dd41aeaf18a71fe20c0c0c08e9521` |
| L3 | N | `source-v01` | `9a53c7ca04e363e0d023a667a84de6ad26a7a5af2deaeb7cf2eb123ce5f7f881` |
| L3 | E | `source-v01` | `180e0cad4da66d5180b1fd3bd5df98d5e524e0924827002d3065a93811ec1e9c` |
| L3 | S | `source-v01` | `b6f709d0e4d56c4e13c7e69293891bc599dc706d8ceadddf87b8377c8dac105c` |
| L3 | W | `source-v01` | `dc5056b8cfdc9676e8db214293f15e86e1dfaf4dc3ee680c420260e2a7adce71` |
| L4 | N | `source-v01` | `b6ed8aaf95e4600bb476934824fab0976cadffe1191f3253aeb19c96cfe2f6b1` |
| L4 | E | `source-v01` | `049ce1b85236c9e443571d925b6def3783cf4226a8b0b9794e47cc195400b5e4` |
| L4 | S | `source-v01` | `cae30c6975f790b05a1de850649f2735a21079bb0c9321673106778f4ca98e34` |
| L4 | W | `source-v01` | `64b51a0bef79104132a508f53f8a1fa567de9bc87c35ecd44c19ef3cc2596646` |

`CROSS-LEVEL-RAW-VALIDATION.json` proves 12 unique raw pixel hashes.
`CROSS-LEVEL-NORMALIZED-VALIDATION.json` proves 36 unique normalized LOD pixel
hashes. The direction-specific scene hashes and normalized file hashes remain
in each level's hash inventory and validator reports.

The accepted Residential L1 candidate at `6380037` remains unchanged and is
used only as a registration and family-style baseline. Commercial and
industrial sources are outside this slice and were not authored.
