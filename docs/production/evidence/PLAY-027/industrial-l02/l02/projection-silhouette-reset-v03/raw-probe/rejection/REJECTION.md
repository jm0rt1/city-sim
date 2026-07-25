# PLAY-027 Industrial L2 East v03 primary probe rejection

Disposition: `REJECTED_RAW_TECHNICAL_AND_VISUAL_GATE`

This record preserves the single Metal-visible East primary process authorized
from pre-pixel commit
`aaa431e867a635d78f70e422caa756efe71d07e8`. It is not source authority,
normalization authority, production selection, or authorization for a repeat,
repair, or another direction.

## Frozen authority

- Descriptor SHA-256:
  `d32c2aaf03cebf53f3821515b19ab03fd86e759687fed9b4bf68eda14e1b65ca`
- Material-library SHA-256:
  `94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6`
- Pre-pixel validation SHA-256:
  `f73a0a077e058845a03ed8cf273babebbab11fec6bd87dce34444ccd20d42a47`
- Preserved v02 rejection SHA-256:
  `7ca9a9dcdbf0552872baecb311eb5459c54d4c186e65ae8f3fa66015020cf4f5`
- Preserved v02 primary-attempt SHA-256:
  `919ba04ee5a76d3f628ee2bb64732a7125c2b0986a8fe8c42aedbcf5ce239b2f`
- Fresh Metal processes consumed: `1`
- Repeat attempts: `0`
- Other directions: `0`
- Normalization runs: `0`
- `productionSelected`: `false`

## Retained governed output

- Governed flat-chroma raw file SHA-256:
  `24e57812ef0d0d024aef8b4d45a2bda9f98c902874b534aed9ff6040707867ba`
- Governed raw decoded-RGBA SHA-256:
  `6748347ef60f9a40fcc0e2faa52564c3fe7b6968260b65715f75a4ac7fea1d83`
- Renderer binary SHA-256:
  `34fad40cb6064d36c953eb1b857084eac36757396f47adddeeae1f5911e05815`
- Renderer source SHA-256:
  `2cc0aa1eafd3fcbf987bce25f4ab6ef8e2f54cae2fb2974951a990e83c104ece`
- Review binary SHA-256:
  `65caf193d56ff56edf55fbd1ee6b00e8066e19c58e6082e6db37c0411bded93f`
- Review source SHA-256:
  `ab3c115ce94bb43798742ab8fad26f7676749a89cf90923b9580654686dc98f8`

The governed raw, genuine pre-chroma alpha intermediates, neutral composite,
provenance, metrics, inventory, and every generated review panel remain
retained under the sibling `diagnostics/east-primary` and `review` directories.

## Passing gates

- Metal capability was present on Apple M5 Pro.
- Rendered root bounds remained complete at X/Z `[-28, 28]` and
  Y `[0, 35.650001525878906]`.
- Raw non-chroma occupied bounds were 520 by 418 with 146,141 pixels.
- Hidden RGB count was zero.
- Neutral proof magenta-family count was zero.
- Registration passed for the footprint diamond, ground pivot, East frontage
  socket, door bases, and southeast shadow vector.
- Building-only span was 514 source pixels / 144.5625 native-2x pixels.
- Core-form span was 422 source pixels / 118.6875 native-2x pixels.
- The minimum governed feature span was 17.15625 native-2x pixels.

## Binding failures

The frozen value hierarchy did not survive the governed render:

- p25 was `48`, below the required `80`.
- p75-p25 was `39`, below the required `48`.
- p95 was `148`, below the required `192`.
- The largest occupied step-32 bin share was `0.46409793089147916`, above the
  maximum `0.35`.
- Although six step-32 bins were occupied, 116,020 of 135,034 building pixels
  fell in the 48 and 80 bins, confirming broad tonal compression.
- The flat-chroma raw retained 8,460 opaque near-magenta edge pixels, failing
  the frozen chroma-spill gate even though the genuine neutral alpha composite
  contained zero magenta-family pixels.

Literal source and native-2x review also show the same failure mode: the wide
footprint and three doors survive geometrically, but dark hall/loading masses
collapse together, the roof remains dominant, and the administration,
production, and loading hierarchy is too weak at native-2x for source
authority.

No rerender or repair was attempted after this rejection.
