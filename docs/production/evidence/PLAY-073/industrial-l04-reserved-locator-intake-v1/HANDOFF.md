# PLAY-073 reserved Industrial L4 locator intake

## Outcome

Renderer now has a strict, test-only consumer for Integration's exact
East/South/West source-candidate locator authority at `fa66b560`. It pins both
the schema and instance hashes, validates their closed semantic shape, and
maps each exact absent packet path to a deterministic nonshipping reservation
receipt.

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
5. Final refreshed evidence commit.

Import only these focused descendants; do not merge the older renderer branch
range. A future source packet must still pass source-stage-v2, independent
Integration admission, Renderer quarantine, and the exact 4/4 join.

## Stop conditions

Stop on missing or changed authority, path/hash/schema drift, a preexisting or
symlinked reservation, sibling alias, North substitution, any source packet
creation, or any request to activate runtime/shipping surfaces without a
separate authority.
