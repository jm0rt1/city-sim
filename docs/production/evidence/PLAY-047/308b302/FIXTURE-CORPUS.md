# PLAY-047 Production Story-State Corpus Evidence

- **Authority:** `39980d753a566a2a4ea68e320f059d8046d051b7`
- **Preserved PLAY-046 head:** `d89e2a91372d0a5dc36e9398309b3a29e0fd45ae`
- **Authority merge:** `2595efc23933599f07995f02d67ac8f408bd5e0f`
- **Fixture/test commit:** `308b3026d4f8d25485dd93d2808b5c7fe654d9eb`
- **Schema:** 1
- **Fingerprint version:** 1
- **Seed:** 42
- **Manifest:** `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-states-manifest-v1.json`
- **Manifest bytes:** 4,860
- **Manifest SHA-256:** `aa62273943debe4b841a324584468a1953039f1a399e570321cbca46f4dcb000`

## Frozen corpus

Each file is an unmodified schema-1 envelope written through the production
`SaveGameService`. Two independent test-owned builds produced the same eight
states, bytes, file hashes, fingerprint-v1 state digests, and spatial
snapshot digests. Five consecutive fingerprint computations also agreed for
every state.

| Strategy and moment | Tick | Bytes | Fingerprint-v1 state digest | Spatial-v1 digest | File SHA-256 |
|---|---:|---:|---|---|---|
| Commercial opening | 64 | 131,914 | `3ae32cf46bff29d5d9ffb9ecc8de0ea78d7d002fec0058a784b43c3410d11772` | `bbdb960502c9b027c609970dfd5ebde2e0a68d19e927bfd9c613097e2ae3aa38` | `71e0ed73172d295d53e0f4859e63c9262c43bb2339f1a983d4fd2f5a028ba06d` |
| Commercial complication | 128 | 132,916 | `ac0e7cb4c690df2854f2f0a5481c05d6239a336b8995f2c23c3e619250633bfb` | `dd579881b4a3e69c7344083554c0eef60af78d6b75dcb0c1281a46b7536b8ed6` | `c69b0695510f9b7ecde695e70fae281a165f70cc81f6962842019ba461994776` |
| Commercial recovery | 256 | 132,854 | `53fe959a7f8fc6894b6170e006e0d3e0d7f49cbc25cb1bb8cc3d717e84e6239f` | `be990b93b90ac64d2592c37fd3b080fb434255fc1028b2c7128f2a9dbf1a851c` | `ccf0cc8a7e061aafd6deab26c7f53731152736f6011aa6e066a6bd1bf59e6ad4` |
| Commercial Charter victory | 844 | 133,166 | `13933981fbaed7ccf5b2228bc40bb1d5435072f7b740affb7b05d25fea5d3083` | `8bf2b789d644389d7f6bacf93d91085f3e8e1956f09b48cd121342876dad13d8` | `7125e4d15caf89b1e5c68d38661240f20e920f4dab24bcab78ac6c3132235109` |
| Industrial opening | 64 | 131,891 | `4fed94e2ba6a3a06eb84fc9db44a9c671268077cacfbba3f3e03f62167037d0f` | `c999a2fe4865d9de13f82f9ed50e734735b8fa73a9ccfbab7d54549e3bda8504` | `2eb0e82c14db0819ceb53bfee6c695bc2747718cba90944abbe4dd92195e6a18` |
| Industrial complication | 128 | 132,912 | `37c1cf4e620c8af5741fd9f4b4acfa9b7976d49f6149ec88475ac2b260f1529e` | `de611c63c11a2c2004e329b5dccc9d60193ceb547895f79c4bcf9992bef1bd90` | `660ed6a93c54b7e853e4fc6e9388e29d048b5bdbaefdd5cde066ca5be0dc05f1` |
| Industrial recovery | 256 | 132,865 | `ba6bcfd17094929fed45cd5dc94b209eec16ede7cfab6acfc39c53a30da24ff0` | `c4bc35763526ab8fc7dc7692110f69094f2b0c56f48561f812cd8912169f15f6` | `bf049f80aaa6dd472df380bfafc9a8bbe8a3c1f590c7b52a06973e9361a2a1c9` |
| Industrial Charter victory | 844 | 133,229 | `670a8fc6a7a8d23a3c07b8119a87161215cd7b0eaa15b5867e967163c2c461e3` | `ed964ee4678eaaab4ee1db9bf43efaed6d4bb699b7ef4c0783d7bd86c510a203` | `45e98dda7a13e432bb842f81adb34719549f7c68a35dcfb778518d3d4393597a` |

Commercial fixtures use the existing Commercial Tax Relief recovery;
Industrial fixtures use the existing Industrial Utility Expansion recovery.
Opening, complication, recovery, and terminal states retain their authoritative
strategy, phase, selected resolution, analytics, message, simulation status,
and Charter-award identity.

## Contract proof

`ProductionStoryStateFixtureTests` proves:

- production primary and backup loads return every exact state paused;
- primary loads retain `City loaded · Simulation paused`, while backup-only
  loads retain `Recovered last known-good city · Simulation paused`;
- load clears undo, and a post-load Undo cannot mutate the restored state;
- independent replay reaches the exact next frozen state at every boundary;
- every playing fixture supports an exact one-command undo;
- Charter-victory fixtures reject further commands and remain immutable;
- retained `CityPresentationSnapshot` and spatial samples do not mutate when
  their source state changes;
- schema-0 and schema-1 authentic legacy files retain their original bytes,
  SHA-256 values, and fingerprint-v1 digests.

The authentic legacy fixture values remain:

- schema 0 file SHA-256
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`,
  state digest
  `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5`;
- schema 1 file SHA-256
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`,
  state digest
  `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f`.

## Commands and results

- Explicit corpus generation:
  `CITYSIM_PLAY047_WRITE_FIXTURES=1 swift test --filter ProductionStoryStateFixtureTests/testWriteFixtureCorpusOnlyWhenExplicitlyRequested`
  — 1/1 passed; the writer required two identical independent corpora before
  replacing the committed test resources.
- Focused PLAY-047 suite:
  `swift test --filter ProductionStoryStateFixtureTests`
  — 5/5 passed in 6.498 seconds.
- Platform matrix:
  `swift test --filter '(ProductionStory|Session|StrategyResolution|TerminalVictory|Spatial)'`
  — 38/38 passed in 26.303 seconds.
- Complete native suite:
  `swift test`
  — 164/164 passed in 413.927 seconds.
- `git diff --check` — passed.
- `bash -n script/build_and_run.sh` — passed.
- `bash -n script/persistence_relaunch_gate.sh` — passed.
- `./script/build_and_run.sh --verify` — passed for exact product commit
  `308b3026d4f8d25485dd93d2808b5c7fe654d9eb`.

The final complete-suite corpus builds took 1,499.150 ms and 1,489.861 ms.
Per-fixture measurements ranged from 1.137–1.223 ms for fingerprinting,
2.242–2.436 ms for immutable snapshot construction, 9.064–9.443 ms for save,
and 2.836–3.186 ms for load. Fixture envelopes range from 131,891 to 133,229
bytes. Every value remains below the existing 2 MB envelope, 500 ms
fingerprint/snapshot, and 1,500 ms save/load ceilings; the full corpus stays
below its 5,000 ms generation ceiling. Retained spatial storage remains under
128 KiB.

The unchanged dense diagnostic retained state digest
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`
and 136,367-byte envelope.

## Runtime isolation

The fixture support and JSON files are test-target resources only. The staged
production app contained no `StoryStates` files and its executable contained
no PLAY-047 builder, writer-environment, or `ProductionStory` symbols. The
staged candidate used identity
`com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, isolated data
root `dist/test-data/simulation-platform-w8bb1822a1e25`, and manifest
`dist/manifests/simulation-platform-w8bb1822a1e25.manifest`. Its exact
verified PID `8901` was terminated after proof.
