# PLAY-099 Claim — deterministic South derived-LOD repair

- **Title:** Rebuild blank Industrial South derived LOD payloads
- **Lane:** World Art family coordination
- **Owner:** Agent 006 World Art Director, thread `019fec54-216e-7af0-99b8-3d451f36fe26`
- **Branch/worktree:** `codex/citysim-world-art-play101-industrial-l01-v0-family` at `/private/tmp/citysim-play101-industrial-l01-v0-family`
- **Published base:** `b246fb981a5ecc89e6f1a5ca30f8dd782dd68199`
- **Status:** active for one outcome lease and one coherent repair commit.

## Exact repair boundary

The twelve Industrial South raw masters and twelve populated `source-rgba.png`
files are immutable inputs. Rebuild only the 36 blank derived
`block.png`/`neighborhood.png`/`city.png` payloads under
`Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/normalized/south/`
using dependency-free premultiplied bilinear resize. Two isolated fresh-root
replays must be byte-identical to each other and to the adopted repository
payloads.

The maximum mutable set is exactly:

- `Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/repair_south_derived_lods.py`;
- `Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/validate_south_admission.py`;
- the 36 derived LOD PNGs named above, excluding every `source-rgba.png`;
- the twelve identity receipts and `receipts/south/all-south-receipts.json`;
- `provenance/south-admission-provenance-v3.json`;
- `handoff/PLAY-099-industrial-south-admission-v3.json`;
- `process/south/normalizer-build.json`;
- `docs/production/evidence/PLAY-099/south-admission-report-v3.json`; and
- `docs/production/evidence/PLAY-099/south-batch-evidence-v1.json` only if its existing South process/hash projection must change.

The strengthened validator must require correct dimensions and recorded
hashes, nonempty alpha and RGB, zero RGB behind zero alpha, zero frame-edge
alpha, and 36 unique derived payload hashes. The existing PLAY-099 admission
validator must pass after the two deterministic replays.

## Immutable and excluded

All raw masters, all `source-rgba.png` files, rejected source-v02 evidence,
North/East/West bytes, product/runtime/resources/build/QA files, claims other
than this activation, and the four inventoried untracked PLAY-101 family drafts
are immutable. This repair grants no source admission, family admission,
renderer quarantine, runtime selection, production activation, app/build/QA,
push, release, or self-acceptance authority.

Stop on any immutable-input drift, nondeterministic replay, empty derived
payload, hidden RGB, frame-edge alpha, wrong dimensions/hash, duplicate derived
payload, unexpected path, validator failure after the bounded repair, or
protected-draft drift. Stage explicit changed paths, prove the unrestricted
index contains only the allowed repair packet, and create one commit with
subject `PLAY-099: Repair South derived LOD payloads`.
