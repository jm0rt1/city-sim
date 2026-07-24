# PLAY-023 Generated-v4 Pipeline Evidence

- **Exact product:** `38e2134dd700a3d32c2bae201acbd4b0cca3aa38`
- **Accepted beauty baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged bundle:** `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- **Pack:** `generated-v4-calibration`, schema 4
- **Manifest SHA-256:** `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72`
- **Disposition:** author evidence complete; not self-integrated

## Deterministic build and registration

Two fresh atlas roots were each seeded only with the immutable rollback
sentinels declared by the manifest, then built independently with
`build_world_asset_pack.py`. `diff -rq` reported no differences. The generated
manifest and four production pages were byte-identical between builds and to
the checked-in source:

| Artifact | SHA-256 |
|---|---|
| `generated-v4-manifest.json` | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |
| `pages/block/page-00.png` | `294722acd6265c6e48cfba8d542feeb42bda9fdd17f7f0ca16bbb734eca7e237` |
| `pages/block/page-01.png` | `ff83db21bd739b3eba938c55bd0ab3ff8187a6c7d9575a89560a27032ad2d7f6` |
| `pages/city/page-00.png` | `21d05fe9eb6c4b11ddf1772295960e61da67adaa069014116a812c3320b4822e` |
| `pages/neighborhood/page-00.png` | `8d2094b3047c35e59212aa93557da176bc1c20dcef3035a4fb0c022e851d29c2` |

The production validator passed with 84 payload-pixel digest checks, 84
padding/extrusion checks, 974 packed-overlap checks, 133 retained
source/provenance records, all 16 road masks at all three LODs, and zero
cross-LOD ground-pivot drift. Alpha remains RGBA, pages are power-of-two and at
most 2048 pixels, and no unpacked generated-v4 payload remains in the shipping
bundle.

The physical validator passed 324 reciprocal ground-contact checks, 36
building/road-setback checks, and 256 entrance/prop-exclusion checks with zero
collisions, missing inventory references, or orphan generated-v4 pages.

## Runtime loading, residency, and rollback

`WorldAssetCatalog` loads only manifest-declared `Bundle.module` pages,
verifies page SHA-256 before registration, slices deterministic texture rects,
prefetches only one adjacent LOD, and evicts pages outside that bounded set.
The focused suite exercised repeated real LOD transitions with zero fallback:

| Active detail | Active plus adjacent decoded bytes |
|---|---:|
| City | 10,485,760 |
| Neighborhood | 33,554,432 |
| Block | 33,554,432 |

Missing logical assets and unknown pack overrides emit explicit bounded
diagnostics. `CITYSIM_WORLD_ASSET_PACK=legacy-v2` was exercised against the
exact staged app: it launched successfully and visibly used the retained
legacy resources without changing gameplay or save contracts. The normal
production launch emitted zero fallback diagnostics.

After three hands-on LOD cycles and more than 60 seconds:

| Window | Settled RSS | Ceiling |
|---|---:|---:|
| Default | 149,792 KiB | 333.8 MiB |
| Exact 900 x 600 content | 207,456 KiB | 333.8 MiB |

The focused diagnostic retained 1,138 default nodes / 406 drawables and 1,129
compact nodes / 397 drawables. Its cold profile measured 3.979 ms world update
and 4.768 ms total render. The unchanged-pulse soak retained node/action
identity and averaged 0.0007 ms.

## Tests and staged identity

- Focused `WorldRenderingTests`: 41/41 passed.
- Full native suite: 190/190 passed in 90.983 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at exact product `38e2134`.
- Source/staged pack validation: passed with identical manifest and page bytes.
- Staging manifest SHA-256:
  `150308e7cf6e425d0744f8f26599fe48b3483244bdb485c3106924a2dc751548`.

The exact staged app was operated at default and documented compact mode. The
accepted connected district remains the dominant composition, the three
camera LODs remain distinct and usable, the City map AX surface remained
focused/addressable, and repeated keyboard zoom/frame operations preserved
hit-test stability.

## Retained live proof

| File | Pixels | SHA-256 |
|---|---:|---|
| `live/default-block.png` | 1278 x 768 | `c75d285a1c6151c0686c8da0cb7796298eb0e2e217580e1683cde168122173f2` |
| `live/default-neighborhood.png` | 1278 x 768 | `df18c08307e5b046b87a43429c6bb65156bfc24d4df5b5834ba16d4c1f353cec` |
| `live/default-city.png` | 1278 x 768 | `f56b67b0026ed4e56fb60636e42775fdffd38deae2c3292baf941aba8d82ec93` |
| `live/compact-900x600-content.png` | 900 x 652 window, exact 900 x 600 content | `65a8b78df1b71d2f64546adbd636220cbf2a8a26847263c91b769e94f5a1c95a` |

The page conversion preserves all 84 accepted payload pixel digests. No new
art was generated and no aesthetic, camera, gameplay, HUD, save, Package.swift,
or build-script contract changed.

## Evidence-file hashes

| File | SHA-256 |
|---|---|
| `validation/source-pack.json` | `a5150438e0f1ffedb1b0e25807826bae01ff18d56ca92b0097e174c02c5e0c42` |
| `validation/clean-build-a.json` | `a5150438e0f1ffedb1b0e25807826bae01ff18d56ca92b0097e174c02c5e0c42` |
| `validation/clean-build-b.json` | `a5150438e0f1ffedb1b0e25807826bae01ff18d56ca92b0097e174c02c5e0c42` |
| `validation/production-geometry.json` | `059031e2a05930b115982773220b05812b35da8550bb46e63346a9549a9eab04` |
| `validation/staged-pack.json` | `b9ac6497e65f579d3e498ae84cd4b3ccb9aa09b08d34b51ae194b3b5778215f0` |

## Limitation

The staging script is integration-owned and was not changed. Pack identity and
digests are retained by the renderer validator and this packet rather than
adding new fields to the integration staging manifest. Consumers can verify
any staged bundle with `validate_world_asset_pack.py --atlas <source>
--staged-atlas <bundle-atlas>`.
