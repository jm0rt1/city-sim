# PLAY-027 Commercial L4 West 4x sampling diagnostic rejection

> **Superseded raw-only interpretation:** This note preserves the initial
> overstrict raw-review disposition. Integration subsequently established
> that accepted Commercial L4 West source-v03 has the same occupied bounds,
> occupied-pixel count, and opaque magenta edge treatment. The binding final
> disposition for this packet is therefore
> `PENDING_NORMALIZED_CALIBRATION`, as recorded in
> `RAW-REVIEW-CHECKPOINT.md`. Nothing in this retained note is source
> acceptance or production selection.

**Disposition:** Rejected diagnostic; causal evidence only

**Source authority:** No

**Production selected:** No

**SceneKit/Metal process count:** 3 (West A/B/C only)

**Normalization run count:** 0

The task-owned offline diagnostic pipeline
`play027-diagnostics-4x-no-msaa-software-lanczos-v1` achieved exact
fresh-process determinism for frozen Commercial L4 West `source-v02`.
All three emitted PNG files have SHA-256
`889de4bfb6eda7ae1eed79669918ca5089590a80672eff6ce6a63a3b2126832a`;
all three canonical decoded RGBA buffers have SHA-256
`4ba9c6298e490db091b53c5c4b875002dc2c15f3d9017d4492adcfe549ba6655`.

The candidate nevertheless fails the binding technical and visual chroma
gate. The unchanged exact-chroma review mask exposes 37,766 non-exact
near-magenta pixels, and the source-scale, native-2x, footprint, zoom, and
comparison panels show a bright magenta fringe around the building and
footprint/shadow field. Determinism does not make these pixels acceptable.
No normalization was run, and the failed pixels were not despilled or hidden
by review tooling.

The next proposal must prevent background contamination before or downstream
of resampling while preserving the demonstrated deterministic registration.
It must not reinterpret this rejection, relax the chroma gate, or mutate the
accepted Commercial source.

## Frozen inputs and tools

- Starting commit:
  `8a86b8115a0fc038fa2259d5cf6864549089cdd7`
- Descriptor SHA-256:
  `7ec24286982735476cc377dd3420bec2beafd905ac5443bc1cc0cc390bff27cc`
- Material library SHA-256:
  `ebe723369cf5b01ef471e3ef7bedb286d1eee8e4752c9d6237838fea5a634205`
- Offline renderer binary SHA-256:
  `4b1779f290ad428d94ae3a20b00ba80e393a1f23c4baf9d590c2f4f08f222e24`
- No-Metal review builder source SHA-256:
  `c2563f769efd842ce7c05aab03f7431e39da0c527018c5ae842fc099cee209e1`
- No-Metal review binary SHA-256:
  `f6cb18c7e099d1c68789e6c311119499fd2bb04a8c21782a0e299ff07dafdec0`

## Provenance records

- A:
  `4333f210e140b736ff19c29496e07fd4fcd8aaccb8475e583d64038afc33aed2`
- B:
  `5427b7f826b2a3ff8fdffaafb6c45038a7f029b2358f955fcd7123e5098545f1`
- C:
  `d9a4bd0c2af4ecef7e1ab33875b09f5ef564e0a4d2c59c64cb16f999c9a01f33`
- Review report:
  `7a2054de4e5a25b7672a047535ce6ee9928d0322088eba6b12b44a72c9707dbe`

The authoritative machine-readable metrics, registration fields, comparison
counts, panel hashes, and rejection disposition are in `review/REVIEW.json`.
