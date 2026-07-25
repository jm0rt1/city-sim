# PLAY-027 Residential L3 normalization adoption

The unchanged deterministic normalizer's historical `residential_l01` tool key
selects the frozen residential footprint and pivot registration reused by L3.
It does not supply L1 pixels. Each unique L3 raw source is normalized twice;
the two runs compare byte-identically. The first run's output names are then
changed from `residential_l01` to `residential_l03` without pixel modification.

Per-direction raw tool records preserve the exact invoked key, command, source
hash, temporary filenames, registration transform, and original output hashes.
All twelve adopted L3 output hashes are unique. The shared normalizer and
registration table remain unchanged.
