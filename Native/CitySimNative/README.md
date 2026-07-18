# CitySim Native

CitySim Native is the macOS-first playable vertical slice for the City-Sim vision. It is a real SwiftUI application with a SpriteKit isometric renderer, deterministic simulation, construction economy, population demand, services, objectives, events, overlays, and save/load.

## Run

From the repository root:

```bash
./script/build_and_run.sh
```

Or build and test the package directly:

```bash
swift build --package-path Native/CitySimNative
swift test --package-path Native/CitySimNative
```

## Controls

- Click open land to build the selected tool.
- Click an occupied tile to inspect it.
- Right-click a tile to demolish it.
- Drag the map to pan and scroll to zoom.
- `Space`, `1`, `2`, `3` control simulation speed.
- `Command-S` saves and `Command-O` loads the quicksave.

## Product boundary

This target is a production-minded foundation and complete gameplay slice, not a claim that a multi-year AAA content scope has been compressed into one implementation pass. It deliberately separates pure deterministic simulation, observable app state, native desktop UI, and high-frequency rendering so authored art, Metal shaders, larger maps, networking, and deeper city systems can be added without replacing the app shell.
