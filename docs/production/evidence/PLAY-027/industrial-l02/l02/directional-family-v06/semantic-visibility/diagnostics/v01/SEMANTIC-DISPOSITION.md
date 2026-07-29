# PLAY-027 Industrial L2 V06 Semantic Visibility Disposition

`FINAL_DISPOSITION: SEMANTIC_VISIBILITY_REJECTED`

The task-owned diagnostic gate operated as intended and rejected the V06 North and West descriptors before any governed source-art render. This packet is bound to pre-pixel checkpoint `f3905b81c5a3a0ccd8ad003fb9b56493026063f6`.

Both directions fail the same literal native-2x requirements:

- Dock A retains a contiguous `4 x 21` pixel region, below the required `6 x 8` minimum width.
- Dock A to Dock B has a 1-pixel bounds gap, below the required 2 pixels.
- Dock B to Dock C has a 1-pixel bounds gap, below the required 2 pixels.
- Dock B, Dock C, and the staff entrance independently pass their `6 x 8` visibility requirements.

The labeled masks and machine-readable report preserve the exact production-camera visibility evidence. This is a descriptor rejection, not source authority or an art acceptance. No geometry repair, second diagnostic, or material/source primary is permitted from this checkpoint.

- `sourceRawProcessCount: 0`
- `normalizerProcessCount: 0`
- `southProcessCount: 0`
- `sourceAuthority: false`
- `productionSelected: false`
