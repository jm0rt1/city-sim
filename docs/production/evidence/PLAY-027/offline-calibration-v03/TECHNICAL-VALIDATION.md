# PLAY-027 third residential calibration technical validation

The four-source calibration passes its technical gate and remains pending
independent art review.

- four unique scene descriptor hashes and four unique geometry IDs;
- three byte-identical native processes per final raw source;
- four unique raw file and canonical-pixel hashes;
- two byte-identical normalization processes for all twelve LOD outputs;
- twelve unique normalized file and canonical-pixel hashes;
- all six review-panel PNGs are byte-identical on independent regeneration;
- normalized alpha ranges from 0 to 255;
- zero opaque chroma pixels and zero visible magenta-dominant spill pixels;
- padding, footprint, pivot, frontage socket, projection, northwest key,
  southeast shadow, and source registration checks pass;
- review panels use normalized-alpha block output for native-2x, exact
  footprint, grayscale, and zoom views.

The final deterministic repair replaces only the tiny chimney's repeating
texture with a solid terracotta diffuse value. Facade brick textures,
direction-specific geometry, light, registration, and shadows remain authored
inputs. `DETERMINISM-REPAIR.md` preserves the full failure and repair trail.

Authoritative machine-readable evidence:

- `scene-validation.json`;
- `raw-validation.json`;
- `normalized-validation.json`;
- `raw-determinism.json`;
- `normalization-determinism.json`;
- `CONTACT-SHEET-ORDER.json`.

Technical validity is not art acceptance and does not authorize production
selection, batch expansion, or renderer ingestion.
