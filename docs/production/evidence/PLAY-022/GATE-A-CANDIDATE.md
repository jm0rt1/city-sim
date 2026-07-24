# PLAY-022 Gate A candidate

**Disposition:** submitted for independent integration/playtest scoring; not
self-accepted and not ready for PLAY-023.

## Exact candidate

- Branch: `codex/citysim-world-rendering`
- Commit: `7c54d2c48888f621260d12791e0a578328810048`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle ID: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged app: `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Packaged resources:
  `CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle`
- CONTRACT-005 master ancestor: `fa5b9fec21b5228645e018a7d1f8dfa720655be4`

The staged resource bundle contains the three golden-district exports with the
same retained hashes as the repo atlas: block
`37791fd91ca17d0bb09782ae4556d51874c88fcfb6dd3886d146ff16709fa614`,
neighborhood
`d256c1271a6b71bce8df0b0e6a7c955714b2082e3aac49717eff7b2cb806a696`,
and city
`4b0646d507e10015c67c9b07a7cfd1781eebcbc7cc324fa76eb0ebe7836d60bc`.

## Retained live evidence

All frames are uncropped Computer Use captures from the exact staged app.
Compact captures are 900 pixels wide with 600-pixel content plus the 52-pixel
macOS title bar.

| Proof | Pixels | SHA-256 |
|---|---:|---|
| `gate-a-default-live.jpeg` | 1229 x 768 | `69c55e22f9973216966962cfb55fb678092bab922a018ba7e3dc3bf7581c2088` |
| `gate-a-compact-900x600-live.jpeg` | 900 x 652 | `8b8f86490ea74e8e041fe60c7e8412a9a9f4f7a9b5712c2bc260566f2ee39904` |
| `gate-a-city-live.jpeg` | 900 x 652 | `bf7fb68a4f7ebd99b3641f6d80595691cd2ac5ca7e8bfcd10e3af7491ce48063` |
| `gate-a-neighborhood-live.jpeg` | 900 x 652 | `8b8f86490ea74e8e041fe60c7e8412a9a9f4f7a9b5712c2bc260566f2ee39904` |
| `gate-a-block-live.jpeg` | 1278 x 768 | `7e73777739fc097f1c3698dd02325275fa889be08a2d70669db428937e684ccf` |

## Verification already completed

- `bash -n script/build_and_run.sh`: passed after CONTRACT-005 synchronization.
- `./script/build_and_run.sh --verify`: passed at exact commit `7c54d2c`; the
  manifest reported the packaged resource path above and the live app loaded
  the authored district from it.
- Focused Gate A renderer/camera/masking tests: 3/3 passed after the default
  camera and covered-lot repair; the final compact camera test passed 1/1.
- The pre-synchronization Gate A implementation passed the complete 24-test
  renderer suite and 121-test Swift suite. The last two commits change only
  camera composition, covered base-lot visibility, and their focused tests.
- Prior soak remained stable across 4,286 unchanged pulses: 10,295 nodes,
  2,508 drawables, 6 actions, and 1.1980 ms average pulse.

## Review request and limitations

Integration directly inspected all five retained frames. Independent reviewers
must now score composition, coherence, depth, life, interaction legibility, and
compact quality under the PLAY-022 directive. The candidate is not accepted by
this lane.

No continuous pan/zoom recording is retained; live LOD transitions were
exercised while obtaining the city/neighborhood/block frames. The complete
Swift suite was not rerun after the final camera-only compact adjustment.
PLAY-022 remains active until the independent score arrives. The monolithic
plate is a Gate A style anchor, not final generated-v4 gameplay geometry.
