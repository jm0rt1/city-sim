# Initial center-ray proof failure

The isolated fixture descriptor emitted identically in two processes, but the
first proof aimed only at the inset back-plane center. Under the fixed oblique
North camera that ray grazed:

- `fixture-opening-jamb-right` at distance `168.64144679512253`;
- `fixture-opening-lintel` at distance `168.64144679512253`.

Exact failure:

```text
FAIL camera ray hits solid before back plane [("fixture-opening-jamb-right", 168.64144679512253), ("fixture-opening-lintel", 168.64144679512253)]
```

This is a diagnostic-selection failure, not an aperture-overlap pass. The
fixture scene SHA-256 was
`3cfcd3cef9b405b31a156eb2b22ba1efbef91694e6c87e7b7331e0d88991c78d`
in both processes. No panel or structural PASS receipt was emitted.

The corrected proof deterministically tests a fixed 3-by-3 set of interior
back-plane points and requires a ray that enters the aperture AABB before the
back plane with zero positive-mass intersections.
