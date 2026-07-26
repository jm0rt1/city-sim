# PLAY-027 Industrial L2 East source-v07 rejection

## Disposition

REJECTED. The frozen pre-Lanczos transform converges three distinct SceneKit
4x frames to one exact canonicalized frame, support window, downstream stage,
decoded final image, and PNG file. It therefore passes the narrow deterministic
identity gate.

It fails the binding visual-quality gate. Literal comparison against frozen
source-v06 shows a stronger multi-banded southeast/contact shadow and a
perceptible facade/material palette shift at native-2x scale. The grayscale
panel also retains the shadow-value shift. Mathematical identity does not waive
that regression.

No normalization was run. `productionSelected` remains false. The source-v05
and source-v06 rejection trees remain immutable.

## Exact evidence

- pre-render contract commit:
  `fbe83200e2243ec48c68048206abcb5b14108d6a`
- renderer binary SHA-256:
  `df8ef43361dabb64ba8132c6ba050b0a950d7f6260df80aafe9dee3553cdca06`
- descriptor SHA-256:
  `69c2d2b37e65c91fb19e6c1f3b913e4f00a22558694fdd87b97a9942c6ed6a90`
- material SHA-256:
  `4f4e34aa87891d70c442e596315bcbd474f059638c0af69abe6ecaac17af0815`
- canonicalized 4x SHA-256, all runs:
  `afb8c0d81eaffc121a12fb025fbcfd611b80bffba5c27baad632d1a4c0d29c40`
- target 33x33 support SHA-256, all runs:
  `f9ac17bfa8738845e0837db7ea96d3cb5a3e7a62dd493e70c0f14a3b12a5c05e`
- final decoded SHA-256, all runs:
  `00e16c0c72b6061e514ef1d0bd397d103deb6a6c06e1873ac0d2e87d9dbf4faa`
- final PNG SHA-256, all runs:
  `c70bbd2bdf71ab0bc2c1a2c529ea51e1618d90dd50d8b10bc3ee1dcf3ec771eb`

The v07 final differs from frozen v06 at 4,727 decoded pixels and 6,452 RGB
channels. Alpha differences are zero, occupied bounds remain exactly
`[619,597,1029,906]`, and the largest per-channel change is one quantum (32).
The changed-pixel bounds `[661,599,877,822]` include the southeast/contact
shadow and multiple facade/material regions. This is a color/value regression,
not a silhouette or registration movement.

Review panels:

- `review/NATIVE-2X-COLOR-V06-VS-V07.png`
- `review/NATIVE-2X-GRAYSCALE-V06-VS-V07.png`
- `review/NATIVE-2X-DIFFERENCE-X4.png`
- `review/SOURCE-SCALE-CROP-V06-VS-V07-DIFFERENCE-X4.png`

Panel order is frozen source-v06 at left, rejected source-v07 at right. The
source-scale comparison adds the amplified absolute RGB difference as its third
panel.

## Smallest next proposal

Do not retune this full-frame step-32 quantizer. Before another source revision,
capture complete pre-canonical 4x RGBA frames from three fresh East processes
and derive a finite, predeclared equivalence table only for the exact unstable
opaque non-chroma RGB tuples. A proposed replacement would:

1. map only members of those explicitly frozen unstable equivalence classes;
2. leave every other opaque RGB tuple byte-exact;
3. preserve alpha, exact chroma, occupied bounds, silhouette, and registration;
4. remain a pure single-frame transform with no cross-run state;
5. fail closed on an unknown tuple or contract/hash drift; and
6. prove native-2x color and grayscale parity against source-v06 before another
   governed triplet.

That diagnostic/freeze requires new integration authority. No replacement
algorithm or source-v08 pixels are implemented here.
