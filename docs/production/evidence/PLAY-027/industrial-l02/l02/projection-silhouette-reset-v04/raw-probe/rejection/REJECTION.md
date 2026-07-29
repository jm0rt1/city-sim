# PLAY-027 Industrial L2 East v04 primary rejection

**Disposition:** Rejected at the raw technical gate. This is not source-art
acceptance or production selection.

Exactly one integration-authorized fresh Metal-visible process was consumed
from clean authority `f35bddcdab0b0ac6c4ed0fd6635c840ae7c4cc5b`.
SceneKit capability preflight, scene construction, bounds validation, and the
single snapshot path completed. Before any PNG or provenance file was emitted,
the new task-owned v04 straight-alpha flat-chroma path stopped with exit 133:

```text
v04 compositor changed pre-chroma alpha
```

The first failed stage is the v04 probe compositor's internal alpha invariant,
after post-Lanczos registration and before raw PNG encoding. The frozen
implementation compares the full input and output alpha arrays even though the
approved contract deliberately converts zero-alpha field pixels to opaque
`#ff00ff` (`alpha 0 -> alpha 255`). A nonempty transparent field therefore
cannot satisfy that implementation guard. Foreground alpha behavior, literal
raw pixels, luma hierarchy, chroma fringe behavior, spans, registration, and
visual quality were not classified because no retained pixel output exists.

The diagnostics output directory was not created. No governed raw, pre-chroma
PNG, neutral composite, contact sheet, repeat, normalization, LOD, or other
direction was produced. The v03 rejection trail and every accepted source
remain byte-preserved. `productionSelected` remains `false`.

The smallest next proposal is tooling-only and is not implemented here:
validate the approved alpha relation per pixel—input alpha zero must become
exact opaque chroma; input alpha greater than zero must preserve its original
alpha—while retaining separate hashes for the immutable pre-chroma alpha and
the transformed raw foreground mask. A new Metal process requires fresh
integration authority.
