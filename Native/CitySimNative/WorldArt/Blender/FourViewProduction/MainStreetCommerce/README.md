# CitySim Main Street Commerce — Four-View source family

This bounded source package creates two original low-density commercial buildings: `lantern_row_bakery` and `ironwood_hardware_shop`. Both use the canonical CitySim 88×44 Four-View contract, an exact 4×4-world-unit lot, identity `AssetRoot` and `FootprintPivot`, and the fixed camera/light rig in `pipeline.json`. Cedar Market and rejected vector-family pixels are not used.

Run from any directory:

```sh
./run_pipeline.sh
```

The command builds one `.blend`, four untrimmed transparent 384×384 PNGs, a contact sheet, and a hashed manifest per asset; then it builds two exact-size unified-street previews and runs an independent saved-source rerender validator. A passing report starts with `MAIN_STREET_COMMERCE_FOUR_VIEW_VALIDATION_PASS` at `validation/validator-output.txt`.

The preview and this source directory remain production evidence rather than runtime inputs. Live admission, when accepted, copies exact hashed camNE PNGs into the native resource catalog; the renderer never reads or transforms these source files in place.
