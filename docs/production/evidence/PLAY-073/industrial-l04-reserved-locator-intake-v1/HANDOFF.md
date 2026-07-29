# PLAY-073 reserved Industrial L4 locator intake

## Outcome

Renderer now has a strict, test-only consumer for Integration's exact
East/South/West source-candidate locator authority at `fa66b560`. It pins both
the schema and instance hashes, validates their closed semantic shape, and
maps each exact absent packet path to a deterministic nonshipping reservation
receipt.

The portability repair at `bc999ea7` removes the test's dependency on the
branch-only `IndustrialL4DirectionPacketValidator.sourceStage` helper. The
test now binds the published contract and source-stage schema values locally,
then hashes the canonical published source-stage schema file directly.

No source packet was created or inspected. North remains pending its separate
authority.

## Fail-closed behavior

The focused tests reject wrong authority/hash, unknown fields, wrong path,
wrong direction, sibling path/root alias, every packet-path symlink, and every
preexisting reserved packet. Each direction is exercised independently; a
failed direction leaves previously passing sibling receipt values unchanged.

Receipts keep source admission, Renderer quarantine, runtime activation,
shipping mutation, and production selection false. They are synthetic
intake-preparation evidence only.

## Integration replay

The submitted locator sequence already exists on exact Integration candidate
`80975d472bb61cc7f99e885285e4d970b728823f`. Cherry-picking only the focused
portability repair into a disposable clone produced replay commit
`e8e32858f3ddd7bade2e5a31cc4a2e231489b90e` and passed
`swift test --filter IndustrialL4` with 27 executed,
2 skipped, and 0 failures.

The prior 34-test branch result is also green, but seven of those tests belong
to retained Renderer history that is absent from `80975d47`: three file-harness
tests, two intake tests, one source-admission-schema test, and one exact-join
test. They are not prerequisites of this submitted locator slice and must not
be imported to manufacture the old count. The repaired submitted test compiles
and passes on the accepted Integration surface with no remaining reference to
an unintegrated Renderer helper.

## Exact paths

- Test:
  `Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL4ReservedLocatorAuthorityTests.swift`
- Mapping:
  `docs/production/evidence/PLAY-073/industrial-l04-reserved-locator-intake-v1/RESERVATION-MAPPING.json`
- Validation:
  `docs/production/evidence/PLAY-073/industrial-l04-reserved-locator-intake-v1/VALIDATION.json`

## Import order

1. Published locator authority `fa66b5605deca987685c058a072613e89a0d8be9`.
2. Renderer test commit `8a79db646af3e8db8871cfac62bbe965778fda17`.
3. Initial evidence commit `81fd09f0c992266eb2b34a27a346590f68ff589f`.
4. Explicit authority-drift proof
   `25db1b5a7c4357a5fd24babf41067295dc526a23`.
5. Final refreshed evidence commit `692af6d68ad88b8080ddcb1ea8f7917ed7abd321`.
6. Portability repair `bc999ea7db271d15bb54ee895b4cf9e79c82a3ba`.
7. This portability evidence addendum.

Import only these focused descendants; do not merge the older renderer branch
range. A future source packet must still pass source-stage-v2, independent
Integration admission, Renderer quarantine, and the exact 4/4 join.

## Stop conditions

Stop on missing or changed authority, path/hash/schema drift, a preexisting or
symlinked reservation, sibling alias, North substitution, any source packet
creation, or any request to activate runtime/shipping surfaces without a
separate authority.
