# Copper Arc Powerhouse Refinement

This is a single-asset, source-only refinement candidate for `copper_arc_powerhouse`.
It keeps the live CivicUtilityVariety source asset as the visual baseline and does
not alter runtime resources, source selection, or admission. The candidate retains
the 2x2-tile lot, twin-stack silhouette, canonical rig, and identity root while
adapting the existing Copper Arc authored geometry through the established Density
helper kit. It remains original modeled geometry; no source pixels are reused.

The modeled pass adds articulated turbine-hall side bays, deep industrial glazing,
roof monitor and ventilators, transformer/service-yard detail, and dark inset stack
throats behind raised rims. No image source, texture image, crop, offset, or
per-view compensation is used.

Run the focused candidate only:

```sh
./run_pipeline.sh
```

It writes the `.blend`, four canonical 384px transparent PNGs, contact sheet,
asset manifest, source/dependency manifest, and validation report under this folder.
Successful output ends in `POWERHOUSE_REFINEMENT_VALIDATION_PASS`. This is source
evidence only; the parent integration lane owns native composition and acceptance.
