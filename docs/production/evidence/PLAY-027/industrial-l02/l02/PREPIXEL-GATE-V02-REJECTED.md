# PLAY-027 Industrial L2 source-v02 pre-pixel gate — REJECTED

No pixels were rendered.

Source-v02 made only the governed source-v01 boundary repair:

- gantry posts no longer share a bottom plane with the service apron;
- service tanks no longer share a bottom plane with the dock house;
- the L2 frontage validator now binds the contract-correct 56×56 contact
  polygon and the explicit direction-specific apron centers.

Generic scene validation and the Industrial L2-specific frontage/progression
validator both pass. Structural validation still rejects one exact coincident
Y boundary per direction: the primary apron lane shares its top/bottom plane
at y=3.15 with the service apron. This is an authored structural overlap, not
a renderer or threshold issue.

Source-v02 remains rejected evidence and must not be rendered or normalized.
Any repair must use a new descriptor revision and move only the lane height
off the apron boundary while preserving its footprint, direction, material,
socket registration, camera, and all accepted source bytes.
