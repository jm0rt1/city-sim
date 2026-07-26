# PLAY-027 Industrial L2 East v04 raw-visibility validator repair

Disposition: validator evidence passes; the preserved v04 source-art rejection is not reclassified.

The corrected task-owned raw review validator compares flat-chroma raw non-chroma support with genuine pre-chroma `alpha > 0` support. It no longer discards low-coverage edge pixels by using `alpha > 8`.

Retained evidence replay:

- raw non-chroma support: 146,141 pixels, bounds `(509, 488)...(1028, 905)`
- genuine `alpha > 0` support: 146,141 pixels, identical bounds
- legacy `alpha > 8` support: 141,318 pixels
- `alpha 1...8` edge support: 4,823 pixels
- raw/alpha support mismatch: 0 pixels
- legacy shortfall: 4,823 pixels, exactly equal to the excluded low-alpha edge support

Preservation and authority:

- retained raw SHA-256: `41ba5f09159534438e1a89fc25cf28ccb99ea48bc09d9c3bba80f03f14403072`
- retained pre-chroma alpha SHA-256: `94a4323fe8a6a5da7009a7c0c12b52c4350fe19a3cd5b23d00fd51992a2b35bf`
- retained metrics SHA-256: `83b0b403efcac6b9d8794a036dd69da470acd3d399b5a3a3a7a76bab47fb27b3`
- retained rejection SHA-256: `791a6effab74ca6ff7abedd250908ccf752c22db521b315c3e20100e01b325d3`
- repair validator source SHA-256: `db3dc04424e8dc960ab4e943d98972f0dd208d19474bec89f56aafadee627f48`
- repaired review builder source SHA-256: `5cf7159d3e4e4838a798f5b571b67d7c1787f63338fde6c8b6890257634de594`
- replay validator binary SHA-256: `ddbb55854c39c4501998bb8dd537d8bbb0309e1bb190c0252766c351b75d01f7`
- repaired review builder binary SHA-256: `48a168a7d6ce6c8b362e0fb7c5a017058cd0e008bdc7d3babe90a137129656cc`
- result JSON SHA-256: `5163d30c15819b00d718d795fd541c71b94026907f48dd43c9a6e32d1f0f6c9f`

Both tools compiled with `-parse-as-library -warnings-as-errors` and task-local module caches. The evidence validator ran without SceneKit, Metal, or new pixels. `productionSelected` remains `false`.
