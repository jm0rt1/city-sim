# PLAY-027 north source-v09 deterministic checkpoint

**Disposition:** retained third-calibration review source; not accepted or
production selected

**Renderer-source commit:** `a961cb7`

**Scene geometry:** `residential-l01-v0-north-geometry-v6`

**Scene descriptor SHA-256:** `01cd30eb43b5d3b61676f231c74916d3acd29c45dd03ea154dee42f5b8217053`

**Material library SHA-256:** `cbe7dfb998ae3a96401ca67213eb439249a25b11868a83de48d8f75510bd8b46`

**Raw source SHA-256:** `9f4f4604b397204fd712e04fdbc9f1e50ddcfa775e608730f3aa5638127fe599`

The committed source and an independently invoked repeat render are
byte-identical under `cmp`; both hash to the raw source digest above. The
repeat was written only to `/private/tmp` and is not a second authored source.

North now retains a grounded far-edge porch return with post, lintel, and warm
return light. This checkpoint proves native repeat-run pixel identity before
the east, south, and west descriptors are rendered. It does not constitute
independent art acceptance, authorize batch expansion, or enter the product
renderer.
