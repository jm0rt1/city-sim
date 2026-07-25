# PLAY-027 residual stage isolation — next disposition request

Status: diagnostic stage boundary isolated; no repair proposed

## Preserved authority

The committed Residential L3 West canonicalizer-v2 calibration at `24f8093`
remains byte-for-byte present and unchanged. Its 12 fresh-process result
retains the exact 10/2 split between:

- `23f9a952eaa5650babeb2efea11b4f66215dc31162bc305a45ec719da392b2e7`
  (10 runs); and
- `52011ce067bad07dcca911dbf40cef6b2f9c8c843c8f136859027e21d8f02830`
  (2 runs).

The preserved `RESIDUAL-PIXEL-SPLIT.json` SHA-256 is
`0a84a8d1ed6f5e8515ab1d06bb91d4b244ebf416fc5acfa3d52d2b105a6bccae`.

## Stage-boundary result

Twelve additional fresh processes retained all five requested stages at
source coordinate `(732,778)`. Both prior final PNG identities reproduced;
the diagnostic distribution is 5/7, which is evidence of the same split and
does not replace the preserved 10/2 calibration.

The target is identical through the first two stages:

- prequantized target: `[4,22,2,255]` in 12/12 runs;
- quantized-before-majority target: `[16,16,16,255]` in 12/12 runs.

The target first diverges inside the frozen post-majority canonicalizer:

- 5/12 runs have a 7-of-9 green majority at value 48; the target is eligible,
  mutates green 16→48, and produces final PNG `23f9a952...`;
- 7/12 runs have only a 6-of-9 green majority; the target is ineligible,
  remains green 16, and produces final PNG `52011ce...`.

The local 3x3 input already has two variants before the majority decision.
At neighbor `(733,778)`, a prequantized green value of 23 or 24 lands on
opposite sides of the frozen quantizer boundary, changing the quantized local
green majority from 6/9 to 7/9. The target pixel itself does not vary before
the majority stage.

ImageIO does not reintroduce the target split. In 12/12 runs:

- post-majority decoded RGBA equals ImageIO pre-sips decoded RGBA; and
- ImageIO pre-sips decoded RGBA equals final sips decoded RGBA.

All runs still report 802 total mutations, demonstrating why mutation-count
equality could not identify this residual target-level decision.

## Frozen scope

No threshold was broadened and no additional repair was added. Residential
L4, the full schema-2 regression restart, normalization, and Commercial L4
source-v03 remain frozen. Integration disposition is requested before any
v3 proposal or further mutation.
