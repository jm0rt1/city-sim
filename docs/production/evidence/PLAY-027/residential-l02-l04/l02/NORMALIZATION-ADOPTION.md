# PLAY-027 Residential L2 normalization adoption

The unchanged shared deterministic normalizer currently exposes the frozen
uniform residential registration rule under the historical tool key
`residential_l01`. PLAY-027 invokes that rule for each L2 raw source because
L1 and L2 share the contracted residential footprint and ground pivot.

The raw tool records are preserved per direction as
`normalization-source-v05-raw-tool.json`. They truthfully retain the invoked
tool key and temporary output names. After two runs compared byte-identically,
the first run's three PNGs were moved without pixel modification into the
task-owned L2 normalized directory and renamed from
`generated_v4_residential_l01_<lod>.png` to
`generated_v4_residential_l02_<lod>.png`.

This is registration-rule reuse, not asset aliasing: each output is normalized
from its own unique L2 raw source, all twelve L2 normalized hashes are unique,
and no L1 pixels are copied or referenced. The shared Python normalizer and its
registration table remain unchanged.
