# Industrial L3 South source-v02 repeat stop

South was rendered exactly three times from the frozen source-v02 descriptor,
material library, renderer binary, and sampling contract. Runs A and B are
file- and decoded-pixel-identical. Run C differs from both by 11 RGB pixels
within source bounds `[589, 531, 599, 597]`; alpha differs at zero pixels.

All three outputs are complete and share exact occupied bounds, visible-pixel
count, registration, and alpha. The locality sheet binds the split to two
small vertical-detail regions without changing the complete South silhouette
or frontage.

This is the ordered first-failure stop. West was not rendered and South was
not normalized. No sampling repair is requested. The accepted North and East
immutable masters and their normalized LODs remain unchanged.
`sourceAuthority=false` and `productionSelected=false`.
