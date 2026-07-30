# PLAY-073 external Industrial L3 fixture integration return

## Disposition

`READY_ON_R2_CANDIDATE`

`NOT_READY_FOR_MASTER_ADOPTION`

This follow-up narrows the adoption meaning of the preserved
`cdcd1e92b2864f7f5c5ad879ee015ca2179459bd` checkpoint. The fixture bytes and
intake test are valid only on a renderer candidate that already contains the
unaccepted replacement-R2 Industrial L3 product. The checkpoint is not a
master-independent fixture gate and must not be cherry-picked onto master by
itself.

## Exact prerequisites

- Runtime/product prerequisite:
  `25d291a7373833a797dc3bb3ba36658e18eccc06`
  (`PLAY-073: Replace Industrial L3 with cohesive source family`). This is the
  commit that supplies the L3 `IndustrialGeneratedAssetIdentity` mapping and
  the generated-v4 catalog/pack/runtime payloads asserted by the test.
- Candidate evidence prerequisite:
  `de6805092478c97d85f0230c93f7f10edcb257e6`
  (`PLAY-073: Preserve replacement R2 deterministic evidence checkpoint`).
  Candidate-bound source-to-pack and deterministic evidence claims require
  this checkpoint in ancestry.
- Fixture intake checkpoint:
  `cdcd1e92b2864f7f5c5ad879ee015ca2179459bd`
  (`PLAY-073: Validate external directional fixture intake`).

The admissible ancestry condition is therefore:

```text
25d291a7373833a797dc3bb3ba36658e18eccc06
  -> de6805092478c97d85f0230c93f7f10edcb257e6
  -> candidate descendant containing cdcd1e92
```

Integration has not accepted that product chain. This record does not
authorize adopting it.

## Integration reproduction

Integration cherry-picked only `cdcd1e92` onto exact master
`184e6e5b83b405b217f1908bf331605c8aa0c912` and ran:

```bash
swift test --package-path Native/CitySimNative \
  --filter IndustrialL3DirectionalFixtureIntakeTests
```

The build completed, but the test failed at line 128:

```text
XCTUnwrap failed: expected non-nil IndustrialGeneratedAssetIdentity
```

That failure is expected and fail-closed: master does not contain the
replacement-R2 L3 runtime selection introduced by `25d291a`. Integration
reverted the unpushed cherry-pick; no R2 product was integrated.

## Handoff boundary

- Preserve `cdcd1e92` and its fixture/evidence byte-for-byte.
- Do not weaken the unwrap, add a fallback, or make the test pass on master
  without the exact R2 product.
- Do not adopt `cdcd1e92` alone.
- Re-run the focused intake gate only on an Integration-authorized candidate
  where the exact prerequisite ancestry is present.
- This disposition changes documentation only. No product, test, fixture,
  manifest, pack, or source-art byte is changed.
