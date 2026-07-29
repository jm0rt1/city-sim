# PLAY-027 Industrial L2 source-v10 raw-gate rejection

Status: **rejected at binding first-failure stop**

The physical source-v10 geometry repair remains frozen at
`25c3c2a3f1cc52a958b83089d66af311a6b1553e`. Nine governed fresh Metal
processes were consumed in the authorized order:

1. N/E/S/W primary;
2. N/E/S/W repeat B;
3. North repeat C.

North A and B are exact file-identical. North C is not: its retained PNG hash
is `e78f6160...` instead of `f35b5aa8...`. Standard ImageIO RGBA decoding
localizes the split to 32 pixels and 32 blue-channel values, with zero alpha
differences, inside source bounds `[834,741)–[842,760)`. Occupancy, alpha
bounds, pivot/contact registration, and the complete-volume result remain
unchanged.

The first retained divergent stage is the final sips-canonical PNG and its
standard decoded RGBA. These production runs did not request intermediate
capture, so this packet does not infer whether the causal divergence first
arose in SceneKit, Lanczos, quantization, post-majority canonicalization, or
encoding.

Independent integration review also rejects the art itself. At source and
native-2x scale, L2 reads as dark box massing with a weaker capability step
than accepted Industrial L1. Dock/frontage logic, material depth, staff-scale
cues, and the approved production/administration/process hierarchy do not
survive clearly enough; the saturated magenta footprint plate dominates the
review presentation. This visual rejection is independent of the North-C
identity split.

East/South/West C were not run. No normalization, LOD generation, source
revision, pipeline tuning, or production selection occurred.

No additional repeatability or canonicalization work is recommended against
these pixels. `QUALITY-ROOT-CAUSE-AUDIT.md` records the proposal-only quality
audit that must precede any future source-authority attempt.
