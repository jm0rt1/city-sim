# PLAY-052 combined Round 1E candidate identity

- UI product: `704784b21294562fba5f145455c44e2de2a64e76`
- UI evidence: `88cebf4d141e13b9be357c7d2767e129cde3ca41`
- UI completion: `7de441204611b85cf245c9460c260753ba8efa0f`
- Compatible world product:
  `45dd181221701f7cb73be39b558b7440d86e13b5`
- World evidence:
  `013bdd37c706f2c7326bda870259feb7379570e4`
- Prior independent renderer approval:
  `b2e318cf78c03cbe0490ba12af40a4f0a85100a3`
- Candidate ID: `ui-input-wdbeadac6e0bd`
- Bundle:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Executable:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- Resource bundle:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app/CitySimNative_CitySimNative.bundle`
- Candidate manifest:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/manifests/ui-input-wdbeadac6e0bd.manifest`
- Bundle ID and preference domain:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Data root:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/test-data/ui-input-wdbeadac6e0bd`
- Executable SHA-256:
  `5c812f17cc58f29ab7ab031898d95534a2ee3b960e2a008edd59cdc5001c1181`
- Candidate manifest SHA-256:
  `10fe07d94c8b91b2510529db1c71c7e6b6cb25d9d2ade9a10d84fa076ce3dbc6`
- Packaged generated-v4 manifest SHA-256:
  `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`

## Process binding

Every route began after confirming that no process for the exact executable
remained.

- Fresh exact compact route: sole PID `76269`; all non-`900x600`-named compact
  captures in `live/`; terminated with SIGTERM.
- Explicit regular route: sole PID `76963`, launched with
  `CITYSIM_REGULAR_WINDOW=1`; all `default-regular-*` captures; terminated
  with SIGTERM.
- Explicit compact Reduce Motion route: sole PID `77076`, launched with
  `CITYSIM_COMPACT_WINDOW=1` and `CITYSIM_REDUCE_MOTION_PROOF=1`; all
  `compact-900x600-*` captures; terminated with SIGTERM.
- Final exact-process probe returned no matching PID.

The explicit regular capture is 1278 x 768. Compact window captures are
900 x 652 including 52 points of title/toolbar chrome, proving the required
900 x 600 content size.

## Ancestry

- `45dd181221701f7cb73be39b558b7440d86e13b5` is an ancestor of
  `704784b21294562fba5f145455c44e2de2a64e76`.
- `704784b21294562fba5f145455c44e2de2a64e76` is an ancestor of
  `88cebf4d141e13b9be357c7d2767e129cde3ca41`.
- `88cebf4d141e13b9be357c7d2767e129cde3ca41` is an ancestor of
  `7de441204611b85cf245c9460c260753ba8efa0f`.
- `013bdd37c706f2c7326bda870259feb7379570e4` is an ancestor of
  `7de441204611b85cf245c9460c260753ba8efa0f`.
