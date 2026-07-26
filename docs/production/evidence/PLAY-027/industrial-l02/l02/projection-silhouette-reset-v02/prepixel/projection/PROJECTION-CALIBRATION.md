# PLAY-027 Industrial L2 East projection calibration v02

This is a pre-pixel calibration. It consumes no Metal render process and preserves the complete `920af3b` / `3794912` proof and rejection trees.

The production camera plumbing uses a 6144×4096 SceneKit snapshot, vertical orthographic projection, no MSAA, fixed 4× oversampling, software Lanczos 0.25 to 1536×1024, then the existing compositor offset. SceneKit interprets `orthographicScale` as half the vertical world span. Therefore the old value `158.39191898578665` exposes `316.7838379715733` world units vertically and projects the 56×56 footprint to `255.999980205042`×`128.0000024334846` source pixels. The retained building-only width of 254 pixels is within two pixels of that actual 256-pixel camera projection. The prior 512-pixel analytic claim omitted this factor of two.

Solving through the actual `SCNNode.look` camera basis and every output scale gives corrected orthographic scale `79.1959533691406`. It projects the four corners to the frozen registration diamond within `0.00011988274513896613` pixel, with a 512×256 envelope.

The observed 410-pixel plate is a separate compositor measurement. `drawShadow` scales the 56-unit contact polygon against a 72-unit basis, producing a `398.2222222222222`-pixel core; blur and raster support add `11.777777777777828` pixels. The final 410/512 ratio is exactly `0.80078125`. It is camera-independent and cannot validate building utilization.
