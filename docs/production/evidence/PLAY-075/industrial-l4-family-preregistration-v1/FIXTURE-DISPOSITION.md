# PLAY-075 candidate-neutral directional fixture disposition

## Disposition

`EXTERNAL_QA_FIXTURE_ADMISSIBLE`

The mature-city directional fixture can be represented entirely by QA-owned
evidence files. No product source, shared fixture, save schema, simulation
contract, or hidden renderer override is required.

This fixture is a visual and interaction harness only. It does not prove
Industrial L3 candidate acceptance, simulation balance, progression, or
Industrial L4 product behavior.

## Authority and identity

- Published baseline authority:
  `c08a0aa7b0a461c1dfcd6c50dfe149db5ff766a3`.
- The exact save-model, fingerprint, save-service, and accepted source-fixture
  bytes used to materialize this fixture are byte-identical between the QA
  carrier and `c08a0aa7`.
- Accepted source:
  `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/VisibleCityStates/visible-city-industrial-upgraded-district-v3.json`.
- Source SHA-256:
  `d6e60c425fb240c196655516c236eda1ee5cf7d17ad19b11b2b1149492715826`.
- Source state digest:
  `4da1ab15dc72cfc4227d5197924ee2a29ba7099ec29b65dd009d78d51e08cd3f`.
- Derived fixture:
  `fixtures/industrial-l03-directional-mature-city-v1.json`.
- Derived fixture SHA-256:
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.
- Derived state digest:
  `dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f`.
- Schema/fingerprint version: `1` / `1`.
- Byte count: `133925`.
- Tick/Day: `844` / `212`.
- Seed: `10481999410520546993`.

The immutable machine-readable transformation and placement record is
`fixtures/industrial-l03-directional-mature-city-manifest-v1.json`.

## Deterministic player-visible frontage

Each completed, maintained Industrial L3 lot has exactly one cardinally
adjacent road. The ordinary production frontage rule therefore selects the
declared asset without a fixture direction field:

| Direction | State coordinate | Player block | Sole adjacent road | Logical identity |
|---|---:|---:|---:|---|
| North | `(10,10)` | `11,11` | `(10,9)` | `industrial_l03_v0_north` |
| East | `(3,9)` | `4,10` | `(4,9)` | `industrial_l03_v0_east` |
| South | `(4,8)` | `5,9` | `(4,9)` | `industrial_l03_v0_south` |
| West | `(17,11)` | `18,12` | `(16,11)` | `industrial_l03_v0_west` |

No road tile changed. The four original job-bearing lots were cleared and the
same total job occupancy (`356`) was redistributed as four `89`-worker L3
Industrial lots. All aggregate city fields remain those of the paused accepted
mature-city source. Because this is a paused visual harness, those aggregates
must not be used for economy or simulation assertions.

## Independent validation receipt

Two independent materializations from the accepted source using the existing
`CityGameState`, schema-1 `SaveGameEnvelope`, and
`CityStateFingerprinter` produced byte-identical `133925`-byte output:

```text
state=dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f
file=b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5
tick=844
seed=10481999410520546993
```

The validation also established:

- exactly four Industrial L3 lots;
- exact order-independent identities North/East/South/West;
- exactly one adjacent road for each placement;
- zero road mutations;
- completed construction, condition `1`, and occupancy `89` at every placement;
- preserved job occupancy `356`, aggregate jobs `357`, tick, seed, and playing
  state;
- no serialized direction, camera, renderer, asset, fallback, or LOD override.

## Use boundary

After the Mac is manually unlocked, this exact fixture may be copied into the
isolated data root of a newly admitted exact candidate and loaded through the
player-visible Open flow. It can support:

- the still-unscored replacement-R2 Industrial L3 retest;
- candidate-neutral accepted-L3 harness rehearsal;
- the future Industrial L4 family gate once one exact 4/4 renderer candidate
  exists and the fixture transformation to L4 is explicitly candidate-bound.

Its successful load or static identity never converts the preserved
`de680509` `BLOCK` into an approval.
