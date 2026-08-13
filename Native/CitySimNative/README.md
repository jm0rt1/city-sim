# CitySim Native

CitySim Native is the macOS-first playable vertical slice for the CitySim vision. It is a real SwiftUI application with a SpriteKit isometric renderer, deterministic simulation, construction economy, population demand, services, objectives, events, overlays, checkpoint recovery, accessible controls, and semantic sound feedback.

## Run

From the repository root:

```bash
./script/build_and_run.sh
```

Build the exact branch-isolated `.app` without launching it:

```bash
./script/build_and_run.sh --stage-only
```

Or build and test the package directly:

```bash
swift build --package-path Native/CitySimNative
swift test --package-path Native/CitySimNative
```

## Controls

- Click open land to build the selected tool.
- Click an occupied tile to inspect it.
- Select Bulldozer, then choose a developed tile to demolish it.
- Drag the map to pan and scroll to zoom.
- `Space`, `1`, `2`, `3` control simulation speed.
- `Command-S` saves; use Load City to recover, inspect, or branch checkpoints.
- Open Command Guide in the app for the complete current keyboard catalog.

## Player settings

- Sound effects can be muted and their level persists between sessions.
- Important construction, rejection, save/load, undo, alert, and objective outcomes use restrained semantic cues after authoritative state changes.
- Reduced motion, reduced transparency, increased contrast, and color-independent cues are available independently.
- Every sound-backed outcome retains equivalent visible text and state feedback.

## Product boundary

This target is a production-minded foundation and complete gameplay slice, not a claim that a multi-year AAA content scope has been compressed into one implementation pass. It deliberately separates pure deterministic simulation, observable app state, native desktop UI, and high-frequency rendering so authored art, Metal shaders, larger maps, networking, and deeper city systems can be added without replacing the app shell.
