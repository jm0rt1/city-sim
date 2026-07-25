# Rejected baseline capture attempt 01

This packet is retained because PLAY-056 requires failed visual attempts to
remain inspectable. It is not binding before evidence and must not be used for
same-state LOD comparison.

Integration rejected the attempt before commit because:

- `default-neighborhood-lod.jpeg` and `default-block-lod.jpeg` are
  byte-identical;
- deterministic camera frame `0` was already at the block stop, so the
  attempted additional zoom-in commands were clamped and could not cross an
  LOD boundary;
- the filenames therefore claimed an LOD distinction that the camera state
  did not make; and
- several frames were captured before the load/action transient had expired.

The corrected baseline starts from a fresh exact staged process, explicitly
loads the immutable Day 17 fixture, and waits for the load toast to expire.
Focused renderer diagnostics showed that the keyboard zoom factor skips the
regular window's narrow neighborhood band. The binding capture therefore uses
the existing debug-only `CITYSIM_PROOF_CAMERA_SCALE` evidence hook at scales
whose semantic LOD is independently printed by the renderer test harness. The
corrected record includes distinct hashes and exact scale-to-LOD diagnostics
rather than relying on filenames.
