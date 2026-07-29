# PLAY-027 Industrial L2 quality-reset raw-gate rejection

Status: **rejected and frozen before source pixels**

The first authorized process was North attempt A. The exact descriptor,
material library, binary, and schema-2 v3 production options passed backend
preflight on one visible Apple M5 Pro Metal device. Scene construction then
hit the existing rendered-node completeness invariant and terminated with
exit 133 before SceneKit emitted a candidate raw:

```text
rendered-node bounds do not contain the complete building volume
```

The descriptor declares a 56 x 56 building envelope, so the validator
requires x and z half-extents of 28. The exact approved component envelope is
x `-27.5...27.6`, y `0...64`, z `-28...27`; it therefore misses the
declared negative-x and positive-z completeness extents. This is a pre-pixel
source-authority descriptor/envelope failure, not a Metal availability,
sampling, material, final-PNG determinism, or visual-quality result.

The first-failure stop in the approved raw plan is binding. East/South/West A
and all B/C processes were not consumed. No raw, provenance, normalization,
LOD, production selection, source repair, or rerender occurred. The four
source-v09 descriptors and all earlier rejected/accepted art remain unchanged
at the pre-pixel checkpoint.
