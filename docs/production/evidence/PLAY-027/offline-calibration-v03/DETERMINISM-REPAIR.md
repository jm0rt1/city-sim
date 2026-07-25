# PLAY-027 native source determinism repair

**Scope:** third residential L1 variant-zero calibration only

**Production selected:** no

The first complete raw pass used the committed renderer at `a961cb7`.
Independent process invocations produced:

| Direction | First/third SHA-256 | Second SHA-256 | Differing pixels |
|---|---|---|---:|
| north | `9f4f4604b397204fd712e04fdbc9f1e50ddcfa775e608730f3aa5638127fe599` | same | 0 |
| east | `39feeffc737db64546e53cd35256dde091872ff30b6a359a0b6045012a27612f` | same | 0 |
| south | `370cb84e9cf8e3636bdce569444f8c5395a24aa40b3f754eabf762514fa85c4c` | `15e8cf2d4cab01868fbbdec7d2a7b015f89a17a0048ff260a58d0d12cd426b1e` | 27 |
| west | `4565fee32bf90ffe9c1895e355b0a364c1705307c04d5623e52b08c7f0d7e747` | `af3b90220cc6e95e74e124e4949267cc80d3abe5e3cc76ed911854fa5411f4b5` | 1 |

All differing samples were opaque RGB values separated by exactly 8 in one
channel. A third south and west process reproduced the respective first
hashes, proving a recurring two-state native shading result rather than PNG
metadata variation.

The existing final RGB canonicalizer is repaired before replacement renders.
Instead of rounding to the nearest 8, it maps every 32-value channel bucket to
its midpoint. Applying that rule read-only to both observed states produces
identical pixels for south and west. Chroma pixels remain exempt and the
existing deterministic normalizer remains the sole alpha/despill authority.

The first raw pass and provenance records remain retained as superseded
calibration attempts. All final source revisions advance so that no accepted
four-view candidate mixes canonicalizer versions. This repair does not derive
one direction from another and does not touch the product renderer or shipping
assets.

## 32-bucket probe result

The first replacement pass at renderer commit `44a7798` retained repeat
identity for north, east, and west. South still alternated at twelve opaque
chimney pixels:

- first raw SHA-256:
  `75fd92ee47539c646d893ae23edda03856b38800b708751669e3e6b9a911d385`;
- repeat raw SHA-256:
  `8070d2aec477f89c53a7e226a84a0b922fa3155985e7bf8f0ea8dfd54fdd0a03`.

The values crossed 32-value bucket boundaries, demonstrating that post-color
quantization alone cannot make SceneKit's physically based material shader a
source-art authority. The retained probe is rejected as a set.

The offline source material model now uses Lambert illumination. It preserves
the explicit northwest key and ambient light while removing PBR roughness and
metalness sampling that is unnecessary for the small-scale authored sprite.
The 32-value final canonicalizer remains as a bounded last-stage color
canonicalization. Every direction advances to keep one renderer/material
authority across the candidate.
