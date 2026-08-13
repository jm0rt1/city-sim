# Commercial + Industrial Four-View Production

Original source-only CitySim employment assets produced against the locked
`FourViewPipeline` contract. Nothing here is registered with the game.

Run from this directory:

```sh
./run_production.sh
```

The run creates two Blender sources, four canonical transparent 384x384 views
per asset, labeled contact sheets, manifests, and a composed fixed-grid preview.
It then rerenders into a temporary directory and requires byte-identical PNGs.

