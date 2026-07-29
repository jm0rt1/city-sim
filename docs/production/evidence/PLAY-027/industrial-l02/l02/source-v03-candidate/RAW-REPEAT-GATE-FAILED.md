# PLAY-027 Industrial L2 source-v03 raw repeat gate failure

Status: failed at the first governed repeat-identity check. Industrial L2 is
frozen before normalization pending integration disposition.

The already-authorized B/C batch completed as eight fresh Metal-visible
processes. Every process reported the same `Apple M5 Pro` SceneKit device and
emitted a complete raw with its own provenance and capability record. No
backend-unavailable result occurred.

The first repeat validator invocation was North. It failed:

- primary file SHA-256:
  `f4bcd27762f966057f2c544991bddc28e7b1e6d77fcaad49363880adf502d853`;
- B and C file SHA-256:
  `64baf611427871a60daf9c2048cc9912ada9e47e01f88dacc7ed511e4e2cb02d`;
- primary decoded pixel SHA-256:
  `3e4055f747c2ba828dc4a85ae288a1af485842fc573c5fac6e45692ba6930cb6`;
- B and C decoded pixel SHA-256:
  `2533c09583f02d94f39f4943bd86ff9292455c975d7bfe566644c959cc350f36`;
- unique decoded identities: 2, expected 1;
- all three raws remain complete at 69,418 occupied pixels and 410 x 328
  occupied bounds.

The validator therefore exited 133 and wrote
`RAW-REPEAT-north.json` with `validationPassed:false`. Per the stop rule, no
East, South, or West repeat validator and no normalization was launched.

## Preserved B/C file inventory

The following already-emitted raw files are retained without candidate
promotion:

| Direction | Primary SHA-256 | B SHA-256 | C SHA-256 | B/C byte comparison |
|---|---|---|---|---|
| North | `f4bcd27762f966057f2c544991bddc28e7b1e6d77fcaad49363880adf502d853` | `64baf611427871a60daf9c2048cc9912ada9e47e01f88dacc7ed511e4e2cb02d` | `64baf611427871a60daf9c2048cc9912ada9e47e01f88dacc7ed511e4e2cb02d` | identical |
| East | `3463546dc438daa78f3065c3b169cf02b6d9e34d16635b7da1bf51ad9dbbf967` | `c146afcf52ece4fa3b7c3b601641359c87ad459fb91626d27e69dc051a261abb` | `1a22b9a6bddfad198de8b585c7f319569902c26b63324be2e2ef8eb74b5a2ebc` | different |
| South | `746d064c31d52abf5301611e6a0f6b869ed75ce99c693886e8059ce9d14d37e9` | `746d064c31d52abf5301611e6a0f6b869ed75ce99c693886e8059ce9d14d37e9` | `746d064c31d52abf5301611e6a0f6b869ed75ce99c693886e8059ce9d14d37e9` | identical |
| West | `e0625521e152ee20885ca5151d3ca1633358447722f5fee1f3c3e655dfea8d88` | `e0625521e152ee20885ca5151d3ca1633358447722f5fee1f3c3e655dfea8d88` | `e0625521e152ee20885ca5151d3ca1633358447722f5fee1f3c3e655dfea8d88` | identical |

The East inventory above records file identities only; the stop rule prevented
advancing to its governed decoded-pixel validator. It is not a causal
diagnosis.

The frozen `c0ae6ed` source-v03 descriptors/materials and every accepted
source remain unchanged. No source-v04, geometry/material edit, normalization,
production selection, shipping/runtime/shared/package change, or acceptance
was made.
