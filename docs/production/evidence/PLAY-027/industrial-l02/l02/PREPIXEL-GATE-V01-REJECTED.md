# PLAY-027 Industrial L2 source-v01 pre-pixel gate — REJECTED

No pixels were rendered.

Generic scene validation passed the four explicit schema-2 v3 descriptors,
including unique descriptor hashes, unique geometry IDs, exact camera,
light, registration sockets, authored direction identity, industrial
inventory, and L1-to-L2 vertical progression.

The governed pre-pixel gate then rejected every direction:

- Structural validation found four coincident Y boundaries per direction:
  each of the three gantry posts shared its bottom plane with the service
  apron, and the service tank shared a bottom plane with the dock house.
- The new task-owned L2 frontage validator also contained two frozen
  expectation mistakes: it expected a 60×60 contact polygon rather than the
  contract-correct 56×56 contact polygon, and expected service-apron centers
  at ±25/y2.8 rather than the authored ±23/y2.65.

The first defect is authored geometry and must be repaired in a new source
revision without changing camera, footprint, socket, or validator threshold.
The expectation mistakes must be corrected to the actual frozen registration
contract and independently revalidated. Source-v01 remains rejected evidence
and must not be rendered, normalized, selected, or reused as a candidate.
