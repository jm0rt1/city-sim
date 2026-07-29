# PLAY-027 Industrial L3 source-v03 North raw disposition

Disposition: `REJECTED_REPEAT_IDENTITY`

Exactly three fresh North processes used frozen source-v03 descriptor
`11b559a3...`, material library `3a9b0d97...`, and renderer binary
`d85d05e5...`. All three outputs are complete, share occupied bounds
`[509,387,1027,896]`, contain 159,577 non-chroma pixels, and retain identical
pivot, socket, door, shadow, and building-volume registration.

The authorized pre-Lanczos canonicalizer did not establish exact repeat
identity:

- A/B: 25 differing pixels, 26 RGB channels, zero alpha differences;
- A/C: 20 differing pixels, 21 RGB channels, zero alpha differences;
- B/C: 5 differing pixels, 5 RGB channels, zero alpha differences.

Differences are retained in the exact decoded locality report and
alpha-respecting zoom. This is a sampling/determinism rejection, not an art
rejection. Per the binding stop, no East/South/West source-v03 process,
normalization, catalog work, source-authority proposal, or production
selection was attempted. No repair is proposed or implemented in this
checkpoint.
