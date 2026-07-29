# Industrial L3 cohesion North primary — no-pixel capability failure

**Disposition:** `PRESERVED_NO_PIXEL_FAILURE`. This is not an art rejection,
source authority, family authority, or production selection.

The first governed North source-v04 attempt exited before scene construction
and emitted no raw PNG or provenance record:

```text
Swift/ErrorType.swift:254: Fatal error: Error raised at top level: unknown material: l3-foundation
exit code: 133
```

The retained capability record proves one visible Apple M5 Pro Metal device,
`sceneConstructionStarted: false`, `candidateOutputWritten: false`, and the
requested North descriptor/material paths. `rawPixelCount` is therefore zero.
South and West process counts remain zero.

The failure localizes a pre-pixel validator defect: the committed descriptor
builder mapped and validated only keys named `materialID`, while production
scene construction also consumes role-specific keys such as
`foundationMaterialID` and `trimMaterialID`. The failed descriptor therefore
retained `l3-foundation` and `l3-dark-steel`, which do not exist in the accepted
cohesion material library.

The attempt also supplied an incorrect expanded renderer-source commit string
(`2e4de48bda842d7e0ea0e9e5117f890976783672`) instead of exact checkpoint
`2e4de483f6a5aeae3ecbe0e3a26ec7e5d14f872d`. Because the process stopped before
scene construction and wrote no candidate pixels or provenance, this does not
contaminate a source attempt; it is retained here and must be corrected before
the next governed process.

## Bound hashes

- failed descriptor:
  `89ef4b2fb9a7df869126ffb8b01baf829ba092aeee6f838942d926e67b100b7e`
- accepted cohesion material library:
  `f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65`
- renderer binary:
  `9f975f2a4887dff4888847e8536bf997a89d561f09a84eff9690dca4e90f0bbd`
- retained capability record:
  `cd9d2721b44cd609106e02957e3b9c3b574f676d591b8f1f23389f72994c510c`

The next permitted action is a task-owned pre-pixel descriptor traversal
repair that recognizes every `*MaterialID` key, regenerates N/S/W from their
unchanged accepted v02 descriptors, validates all production-consumed material
references, and replays the zero-pixel boundary deterministically.
