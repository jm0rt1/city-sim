# PLAY-027 North v05 shadow-proof correction

The first zero-render PREDESIGN invocation stopped before emitting proof files
because the new checker incorrectly treated the descriptor's semantic
`shadowVectorSource: [2,1]` token as a literal Blender source-pixel vector.
Under the unchanged v03/v05 camera, the unchanged authored world offset
`[3.5,1.75]` projects to approximately `[-8,+12]` source pixels.

The corrected check requires the semantic token to remain `[2,1]` and the
actual configured-camera projection to remain within `0.001` pixel of the
unchanged v03 baseline `[-8,+12]`. No scene, material, camera, light, shadow,
or rendering setting changed. The failed invocation called no render operation
and consumed no A/B/C process.
