# CitySim Four-View Ground Ecology

Greenworks Nursery is a bounded source-only family of four exact-cell ground treatments and three separately registrable modeled vegetation assets. Every source uses the accepted CitySim Four-View contract: orthographic 2:1 dimetric projection, 45-degree view increments at 30-degree elevation, a top-origin `[192,300]` pivot on an untrimmed 384x384 transparent canvas, `orthoScale=12.341995`, `shiftY=0.28125`, one projected 2x2 world cell at 88x44 pixels, identity `AssetRoot`, and the fixed `CitySimKey` light.

The four ground assets each contain an `ExactGroundCell` mesh with world bounds `[-1,1] x [-1,1]`; every path, wear strip, planted edge, and aggregate inset remains inside that footprint and follows the world X/Y axes. The tree, shrub, and planter assets are original modeled 3D forms with a zero-origin `GroundContact` object and no billboard geometry.

Run the complete production and independent validation pass:

```sh
./run_pipeline.sh
```

The validator opens every `.blend`, checks the root, pivot, cameras, light, projected cell, exact ground bounds, vegetation ground contacts, mesh depth, compensation policy, PNG dimensions and alpha, and manifest hashes. It then rerenders all 28 canonical views and both unified district previews from the saved Blender sources and requires byte-identical canonical PNGs. Nothing in this directory is integrated into native resources.
