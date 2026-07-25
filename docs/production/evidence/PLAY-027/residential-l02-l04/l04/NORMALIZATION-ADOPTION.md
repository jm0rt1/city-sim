# PLAY-027 Residential L4 normalization adoption

The unchanged deterministic normalizer's historical `residential_l01` tool key
selects the frozen residential footprint and pivot registration reused by L4.
It does not supply L1 pixels. Each unique L4 raw is normalized twice and both
runs compare byte-identically. The first run's output names are changed from
`residential_l01` to `residential_l04` without pixel modification.

Per-direction raw tool records preserve the exact invoked key, command, source
hash, temporary filenames, registration transform, and original output hashes.
All twelve adopted L4 output hashes are unique. The shared normalizer and its
registration table remain unchanged.
