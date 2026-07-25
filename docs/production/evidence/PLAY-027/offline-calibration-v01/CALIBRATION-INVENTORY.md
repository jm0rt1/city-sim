# PLAY-027 offline calibration inventory

**Review state:** no source is accepted or production-selected

## Raw attempts

| Direction | Revision | Raw SHA-256 | Disposition |
|---|---|---|---|
| north | source-v01 | `96126e01195bdcc7c13fde41002d9404a4b0039bfbb064ff71fadafc19c06030` | rejected: pre-quantization renderer failed canonical pixel identity; two exact failing runs are retained separately |
| east | source-v01 | `7e45192982df0e550b277944360784d68989f6ac32d563eff66264b15fa8c7a9` | superseded: produced before the deterministic final-pixel repair |
| south | source-v01 | `72f076f61a602adf6a8c127fbc387fd914012604fbc4dad7697197dc5f6091c8` | superseded: produced before the deterministic final-pixel repair |
| west | source-v01 | `718ca45ef90350be56ac7ca23b872d9b9b69dbebd164e0f35708a5b9f2bbedda` | superseded: produced before the deterministic final-pixel repair |
| north | source-v02 | `79061b8ce51f889f8bca427aa01e65529862b54ee7a6e1f5617f9d2e80c3e733` | superseded: repeat-run identity passed, but the later four-view art review rejected this appearance |
| east | source-v02 | `9909a51ba7329313231139ec964dfed34ca084c4e3ff974b62e26895f9e6ce37` | superseded: repeat-run identity passed, but the later four-view art review rejected this appearance |
| south | source-v02 | `ae9553e6f7b928379f6a1521eba358d8bd40413bd55ea5565319525846113351` | superseded: repeat-run identity passed, but the later four-view art review rejected this appearance |
| west | source-v02 | `79061b8ce51f889f8bca427aa01e65529862b54ee7a6e1f5617f9d2e80c3e733` | rejected: exact raw and canonical-pixel alias of north v02 |
| west | source-v03 | `3e216b8e146f91e7bd9c942d094c18f51d3e0235c63cffd0f8eb87cee71a5fc7` | superseded: an initial preview anomaly suggested missing geometry; later byte identity with the complete v04 raster disproved a pixel defect |
| north | source-v03 | `79061b8ce51f889f8bca427aa01e65529862b54ee7a6e1f5617f9d2e80c3e733` | rejected by independent art review after technical validation |
| east | source-v03 | `9909a51ba7329313231139ec964dfed34ca084c4e3ff974b62e26895f9e6ce37` | rejected by independent art review after technical validation |
| south | source-v03 | `ae9553e6f7b928379f6a1521eba358d8bd40413bd55ea5565319525846113351` | rejected by independent art review after technical validation |
| west | source-v04 | `3e216b8e146f91e7bd9c942d094c18f51d3e0235c63cffd0f8eb87cee71a5fc7` | rejected by independent art review after technical validation |

West v02 proves that hidden west-only entrance/prop geometry does not create a
distinct visible source under the frozen camera. It must be repaired in the
west scene itself; no passing sibling may be transformed into its replacement.
West v03 also proves that the review tool preview cannot override retained
bytes: its PNG is byte-identical to the complete west v04 PNG. The v03
revision remains superseded, while v04 is the provenance-bearing member of the
independently reviewed set.

## Independently rejected technical set

North v03, east v03, south v03, and west v04 passed:

- repeat-run raw pixel identity;
- four unique raw and canonical-pixel hashes;
- four unique scene descriptors and geometry IDs;
- raw alpha/chroma/bounds inspection;
- twelve unique normalized LOD hashes with alpha, chroma, and padding checks;
- source-scale, native-2x, and unlabeled grayscale sheet generation.

Integration nevertheless rejected all four as art. The exact visual findings
are retained in `INDEPENDENT-ART-REJECTION.md`. Technical validity does not
authorize source acceptance, production selection, or batch expansion.

## Retained normalization probe

The repository’s existing deterministic normalizer was exercised without
modification by using Codex’s preinstalled bundled Python/Pillow runtime. No
dependency was added to the repository or product. These outputs normalize
the superseded pre-quantization v01 sources and are retained as non-candidate
pipeline evidence.

At neighborhood and city LOD, north v01 and west v01 alias:

- neighborhood:
  `a5e1e64c7f4c9137d84f69dde4ba5998964fe04bf27e1fe6941f491bb0ae9f54`;
- city:
  `708b233c4a9d2cc65c625f956e82b8345c355ca66b6fed123e56506f12f887b6`.

This confirms the same visibility defect at reduced scale. The v01 normalized
outputs are neither accepted nor production-selected and cannot satisfy the
four-direction calibration gate.
