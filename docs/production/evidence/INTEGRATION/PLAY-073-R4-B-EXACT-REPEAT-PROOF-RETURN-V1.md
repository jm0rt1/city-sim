# PLAY-073 R4-B exact repeat-proof return

**Disposition:** one final bounded technical return

**Accepted product geometry:** `1ce6600bf109828962ca85740151965d4219a8c0`

**Returned evidence candidate:** `9cd49210476e589ad848110e6d6061db41c87bac`

**Synchronized clean worker HEAD:** `a01ad44c563d9b2fbf3d9d3a59208ddd896d52c7`

Independent review accepted the renderer geometry, all five-path scope, the
`121 + 3` terrain architecture, civic/park exclusions, interaction negatives,
and lot/service-campus containment. It independently reran
`WorldRenderingTests` with 69/69 passing.

The candidate is returned only because the asserted exact repeat identity is
quantized. `pathSignature` formats coordinates to four decimal places and
`colorSignature` formats components to six decimal places. A smaller real
drift can therefore compare equal while `RESULT.json` and `HANDOFF.md` describe
the comparison as exact.

## Frozen repair

The worker may change only:

- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`;
- `docs/production/evidence/PLAY-073/r4-b-current-master-v1/RESULT.json`; and
- `docs/production/evidence/PLAY-073/r4-b-current-master-v1/HANDOFF.md`.

Replace rounded string signatures with lossless scalar identity. Bind every
path element type and every coordinate component, plus node position,
`zPosition`, fill RGBA, stroke RGBA, and line width, using exact native scalar
bit patterns or an equivalently lossless representation. Add a focused
adversarial assertion proving that a one-bit representable coordinate or color
change is detected. Retain the existing all-family/all-variant/all-frontage
coverage and both containment tests unchanged in meaning.

Do not alter renderer product source, the accepted geometry offsets, terrain
architecture, resources, art, shared authority, gameplay, UI, simulation,
package topology, or scripts. This is the second and final Luna repair attempt:
stop and escalate on any focused failure, required product change, ambiguity,
or path expansion.

Run the two directly affected tests, the full `WorldRenderingTests` family,
JSON validation, exact file/hash/path review, and `git diff --check`. Return
one clean proof/evidence commit. Integration retains the aggregate Swift suite,
staged build, real-app visual journey, candidate acceptance, integration, and
push.
