# Streetscape Continuous

Canonical roadway source family for CitySim's locked 88x44 four-view pipeline. It supplies all 16 topology masks with continuous boundary sockets, modeled curb faces, warm ochre phase-registered center markings, junction-aware line stops, and deterministic connected-network proofs.

Run the complete Blender render and validation pipeline:

```sh
./run_pipeline.sh
```

Expected terminal markers:

- `STREETSCAPE_CONTINUOUS_RENDER_PASS masks=16 views=64 contactSheets=16 previews=2`
- `STREETSCAPE_CONTINUOUS_VALIDATION_PASS`

After validation succeeds, refresh the live camNE catalog with:

```sh
/usr/bin/python3 admit_live_catalog.py
```
