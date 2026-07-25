# PLAY-027 offline calibration inventory

**Review state:** no source is accepted or production-selected

## Raw attempts

| Direction | Revision | Raw SHA-256 | Disposition |
|---|---|---|---|
| north | source-v01 | `96126e01195bdcc7c13fde41002d9404a4b0039bfbb064ff71fadafc19c06030` | rejected: pre-quantization renderer failed canonical pixel identity; two exact failing runs are retained separately |
| east | source-v01 | `7e45192982df0e550b277944360784d68989f6ac32d563eff66264b15fa8c7a9` | superseded: produced before the deterministic final-pixel repair |
| south | source-v01 | `72f076f61a602adf6a8c127fbc387fd914012604fbc4dad7697197dc5f6091c8` | superseded: produced before the deterministic final-pixel repair |
| west | source-v01 | `718ca45ef90350be56ac7ca23b872d9b9b69dbebd164e0f35708a5b9f2bbedda` | superseded: produced before the deterministic final-pixel repair |
| north | source-v02 | `79061b8ce51f889f8bca427aa01e65529862b54ee7a6e1f5617f9d2e80c3e733` | candidate pending four-view and independent review; repeat-run identity passed |
| east | source-v02 | `9909a51ba7329313231139ec964dfed34ca084c4e3ff974b62e26895f9e6ce37` | candidate pending four-view and independent review; repeat-run identity passed |
| south | source-v02 | `ae9553e6f7b928379f6a1521eba358d8bd40413bd55ea5565319525846113351` | candidate pending four-view and independent review; repeat-run identity passed |
| west | source-v02 | `79061b8ce51f889f8bca427aa01e65529862b54ee7a6e1f5617f9d2e80c3e733` | rejected: exact raw and canonical-pixel alias of north v02 |

West v02 proves that hidden west-only entrance/prop geometry does not create a
distinct visible source under the frozen camera. It must be repaired in the
west scene itself; no passing sibling may be transformed into its replacement.

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
