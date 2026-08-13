# CitySim

CitySim is a playable macOS city-building game built with SwiftUI and SpriteKit. The current native vertical slice includes an isometric city, construction and demolition, deterministic simulation, economy and demand, utilities and services, objectives and authored scenarios, overlays, events, save recovery, checkpoints, photo and benchmark modes, accessible controls, and semantic sound feedback.

![CitySim native key art](Native/CitySimNative/Resources/CitySim-KeyArt.png)

## Play on macOS

Requirements:

- Apple Silicon Mac
- macOS 14 or later
- Xcode with the macOS SDK and Swift 6 toolchain

From the repository root, build a branch-isolated app bundle and launch it:

```bash
./script/build_and_run.sh
```

The script prints the exact branch, commit, bundle identifier, save-data root, staged app path, and process ID. Development branches receive isolated app identities and save directories so they do not overwrite the production app or another worktree's city.

To build and inspect the app bundle without launching it:

```bash
./script/build_and_run.sh --stage-only
```

Direct SwiftPM commands are also available:

```bash
swift build --package-path Native/CitySimNative
swift test --package-path Native/CitySimNative
```

## Start a city

The first launch opens Welcome to New Arcadia. Finish the short introduction, then:

- choose a build category and tool from the lower command deck;
- select an open map block to preview and confirm construction;
- select developed blocks to inspect their current condition;
- use the simulation controls or `Space`, `1`, `2`, and `3` to pause or change speed;
- open City Data for finances, population, employment, utilities, history, and resilience;
- use `Command-S` to save and the Load City command to recover or branch a checkpoint.

The in-game Command Guide lists the complete current keyboard catalog. Settings includes sound effects and effects level, reduced motion, reduced transparency, increased contrast, and color-independent cues.

## Product boundary

`Native/CitySimNative` is the shipping product path. It is a complete, production-minded gameplay slice, not a claim that the much larger aspirational AAA catalog has already shipped. The full long-range vision and release requirements live under [`docs/aaa`](docs/aaa/README.md).

The older Python implementation remains in `src`, `run.py`, and related historical documentation for reference. It is not the current player entry point and does not require installation to build or play the native macOS game.

## More detail

- [Native app guide](Native/CitySimNative/README.md)
- [AAA vision and requirements](docs/aaa/README.md)
- [Architecture](docs/architecture/CITYSIM_NATIVE_RUNTIME_ARCHITECTURE.md)
- [Feature catalog](docs/FEATURE_CATALOG.md)
