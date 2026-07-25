# PLAY-027 SceneKit backend diagnostic tooling

Status: frozen before backend execution.

`DiagnoseSceneKitBackend.swift` is a separate task-owned executable. It does
not read a candidate descriptor or material library and cannot render or write
pixels. It records only:

- `MTLCreateSystemDefaultDevice` availability;
- all visible Metal devices;
- implicit and explicit `SCNRenderer` device availability;
- SceneKit rendering API;
- synchronous `prepare` results for an empty scene with a nil abort block,
  an empty scene with a block that always returns false, an empty node, and an
  empty material.

It requires the literal acknowledgement
`PLAY-027-SCENEKIT-BACKEND-V1`, writes only a new JSON report beneath the exact
Industrial L2 diagnostics evidence path, and refuses overwrite.

Validation:

- native compile passed;
- a forbidden `/private/tmp/forbidden-backend.json` report path exited 133;
- the forbidden output was not emitted;
- executable SHA-256:
  `5c16166f55e81afc4d1db335c6f36ac96c9835dc7fa150cbb2dc2162c1af51e4`.

No backend evidence report has been produced from this tooling checkpoint.
