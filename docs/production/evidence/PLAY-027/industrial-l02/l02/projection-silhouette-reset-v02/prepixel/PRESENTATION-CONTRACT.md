# PLAY-027 Industrial L2 East projection and silhouette reset v02

Status: frozen pre-pixel only. `productionSelected` is false and no Metal render process is authorized or consumed.

The exact SceneKit calibration corrects the prior factor-of-two error: vertical `orthographicScale` is a half-span, so `79.1959533691406` maps the frozen 56×56 footprint to 512×256. The separately observed 410-pixel plate is compositor-owned: the 56-unit contact polygon is drawn against the 72-unit tile basis (398.2222 pixels), then blur/raster support expands it to 410. It is not a camera utilization measurement.

The new East scene is a wide, low campus: a 48-unit production hall, 18-unit administration wing, long loading spine, and secondary process/tank group whose vertical element is capped at 26 units. Three 11-unit loading throats and doors have four-unit separations, deep canopies, a grounded apron, and a separate staff entrance. Identity is carried by large volumes and recesses; stacked roofs and a dominant chimney are forbidden.

The later pixel gate must reject unless building-only projected width is at least 420 source pixels and 118 native-2x pixels, every identity cue survives at six native-2x pixels or larger, and the post-step-32 occupied distribution reaches p25 80, interquartile span 48, p95 192, five occupied bins, with no major facade bin above 35 percent.

Neutral review must use genuine pre-chroma SceneKit RGBA alpha. A transparent review context receives the frozen authored shadow and then the pre-chroma building. It never introduces magenta and never mutates the governed flat-chroma raw/source contract. Color-family guessing is forbidden.
