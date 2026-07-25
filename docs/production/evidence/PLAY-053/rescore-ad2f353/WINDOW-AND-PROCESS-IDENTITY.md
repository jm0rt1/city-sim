# PLAY-053 `ad2f353` Window and Process Identity

## Candidate

- Source commit: `ad2f35314bb471a07923c41653374b05ace51ee3`
- Branch: `codex/citysim-playtest-quality`
- Staged candidate: `playtest-quality-wf967be0ab5b4`
- Bundle: `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- Bundle identifier / preference domain:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Executable:
  `CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- Staging-manifest SHA-256:
  `c85c3414b135fcc0394651e8495191fbfa34ed23f4e1576b0fe3abaa2c46abfc`
- Executable SHA-256:
  `2b86a22674883efeacaa4b0f5b2acb91b6ae22281d6144e135d133a9d3df60e9`

The governed stage-only build completed in 1.93 seconds and its manifest
records the exact source commit above. No product file or staged resource was
changed after staging.

## Resolved window-size audit

The first session inherited a prior compact window preference. Its original
Computer Use captures were 900 by 652 pixels. They were excluded before
scoring and removed from the candidate packet after explicit regular and
compact replacement routes were retained.

The scored sessions are explicit:

| Route | PID | Inspected process environment | NSWindow proof contract | Original Computer Use file |
|---|---:|---|---|---|
| Regular | `43383` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play053-ad2f353/regular`; `CITYSIM_REGULAR_WINDOW=1` | 1,278 by 768 content, the repository's regular decorated-window proof corresponding to the 1,280 by 800 renderer fixture | 1,278 by 768 |
| Compact | `45772` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play053-ad2f353/compact-proof`; `CITYSIM_COMPACT_WINDOW=1` | exact 900 by 600 content | 900 by 652, including 52 points of decorated titlebar/chrome |
| Compact interaction | `47951` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play053-ad2f353/compact-interaction`; `CITYSIM_COMPACT_WINDOW=1` | exact 900 by 600 content | 900 by 652 |
| Reduce Motion | `46235` | `CITYSIM_DATA_ROOT=/private/tmp/citysim-play053-ad2f353/reduce-motion`; `CITYSIM_REGULAR_WINDOW=1`; `CITYSIM_REDUCE_MOTION_PROOF=1` | regular proof content | 1,278 by 768 |

The Computer Use files are original window captures, not resized exports.
`ProofWindowConfigurator` is the NSWindow sizing authority: regular requests
1,278 by 768 content and compact requests exactly 900 by 600 content. The
renderer camera contract remains a distinct 1,280 by 800 / 900 by 600 input
contract.

The independently rerun focused camera test printed exactly:

```text
PLAY024_RETURN_CAMERA size=1280x800 scale=0.312796950340271 priority_width=0.7473417931726477 priority_height=1.2329704703499522
PLAY024_RETURN_CAMERA size=900x600 scale=0.576345682144165 priority_width=0.5796985019395197 priority_height=1.58704226315938
```

All four scored-route PIDs were the sole process at the staged executable
path. They were terminated explicitly after capture. Final process inspection
found no process at that path and did not terminate another owner's process.

## Frozen state

Every scored route loaded the committed
`story-industrial-complication-v1.json` bytes as `quicksave.json`:

- file SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- fixture id / seed: `industrial-complication-v1` / `42`;
- tick/day/status: `128` / `33` / `playing`, loaded paused;
- envelope digest:
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`;
- spatial digest:
  `41ef511b0613a33ae643e60b2a934a5a11edbf14a99a422d3f635c9f133fe7e5`;
- City layer, no selection, deterministic `0` camera before each comparison.

The quicksave hash matched in the regular, compact, compact-interaction, and
Reduce Motion roots before launch.

## Source and staged resource identity

Source and staged hashes matched pairwise:

| Resource | SHA-256 |
|---|---|
| generated-v4 manifest | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |
| atlas manifest | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| city page | `21d05fe9eb6c4b11ddf1772295960e61da67adaa069014116a812c3320b4822e` |
| neighborhood page | `8d2094b3047c35e59212aa93557da176bc1c20dcef3035a4fb0c022e851d29c2` |
| block page 0 | `294722acd6265c6e48cfba8d542feeb42bda9fdd17f7f0ca16bbb734eca7e237` |
| block page 1 | `ff83db21bd739b3eba938c55bd0ab3ff8187a6c7d9575a89560a27032ad2d7f6` |

Independent validation reports zero fallback assets and exact source/staged
parity.
