# Industrial L3 raw and normalization gate

The next governed stage is frozen to the descriptor and material hashes in
`ARCHITECTURE.md`.

1. Rebuild the task-owned offline renderer with warnings as errors and bind its
   binary, source, toolchain, descriptor, material, and sampling hashes.
2. Render North, East, South, and West independently in three fresh
   Metal-visible processes per direction. Stop on the first file or decoded
   RGBA repeat mismatch, incomplete occupancy, hidden RGB, chroma, registration,
   frontage, or visual failure.
3. Require four unique raw decoded-pixel identities and empty hash intersection
   with every accepted Residential, Commercial, Industrial L1, and Industrial
   L2 source.
4. Normalize each frozen raw master to block, neighborhood, and city LOD in two
   fresh no-Metal processes. Require byte and decoded-pixel identity for all
   twelve pairs, twelve unique normalized identities, clean alpha/chroma/spill/
   padding, and exact pivot/socket/contact-shadow registration.
5. Bind source-scale, native-2x, registered-footprint, zoom, color, and
   grayscale N/E/S/W panels plus explicit Industrial L1/L2/L3 and
   Residential/Commercial non-alias comparisons.

No renderer ingestion, shipping selection, shared manifest change, or
`productionSelected=true` is part of this gate. Industrial L4 remains blocked.
