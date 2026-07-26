# PLAY-027 Industrial L2 source-v03 primary raw gate

Status: primary raw gate passed; B/C repeat rendering authorized by the
integration disposition. This is not source-art acceptance and does not
authorize normalization by itself.

Exactly one fresh default-renderer process was executed for each of North,
East, South, and West after the capability-preflight tooling checkpoint
`5fa1e4fd71e772bcd765c62c8eda4313fee57b4f`.

Each process reported:

- one visible Metal device;
- system-default and `SCNRenderer` device `Apple M5 Pro`;
- registry identity `4294968844` / `0x000000010000060c`;
- the frozen descriptor and material hashes;
- successful complete-scene preparation and raw emission.

## Primary identities and completeness

| Direction | Raw file SHA-256 | Pixel SHA-256 | Occupied pixels | Bounds |
|---|---|---|---:|---|
| North | `f4bcd27762f966057f2c544991bddc28e7b1e6d77fcaad49363880adf502d853` | `3e4055f747c2ba828dc4a85ae288a1af485842fc573c5fac6e45692ba6930cb6` | 69,418 | 410 x 328 |
| East | `3463546dc438daa78f3065c3b169cf02b6d9e34d16635b7da1bf51ad9dbbf967` | `eda3b8afb56812439d1bbc3425a2fb84b538f58942c386594e12fd512067e0e6` | 67,598 | 410 x 309 |
| South | `746d064c31d52abf5301611e6a0f6b869ed75ce99c693886e8059ce9d14d37e9` | `d38a2f7a443412b2557d32c9784f84a50a28b37d366b2199e4d47a6920e4398e` | 68,925 | 410 x 335 |
| West | `e0625521e152ee20885ca5151d3ca1633358447722f5fee1f3c3e655dfea8d88` | `8ef6b66cfe2a9d8301114c0695550c60b35b994325cef0a9c4d0c4d3e040e568` | 70,838 | 410 x 327 |

`RAW-UNIQUE-PRIMARY.json` passes all four raw checks:

- 4/4 unique decoded pixel identities;
- 1536 x 1024 dimensions;
- fully opaque raw canvas and flat exact-chroma corners;
- at least 50,000 occupied pixels and 400 x 260 occupied bounds.

`EXACT-RGBA-VISIBILITY-PRIMARY.json` passes all four exact-byte checks:

- RGB and alpha-visible occupied bounds match;
- alpha visibility ratio is 1.0;
- zero hidden non-magenta pixels;
- flat opaque chroma corners;
- occupancy remains above the accepted Industrial L1 reference floor.

The literal retained-byte occupied crop shows four complete grounded
industrial volumes, footprint plates, shadows, and separately authored loading
frontages. This visual check authorizes only the required deterministic B/C
processes; independent art disposition remains pending.
