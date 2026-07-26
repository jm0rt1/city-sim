# Industrial L3 East source-v02 repeat stop

East was rendered exactly three times from the frozen source-v02 descriptor,
material library, renderer binary, and sampling contract. All three outputs are
complete and share exact occupied bounds, visible-pixel count, registration,
and alpha. Their file and decoded-RGBA identities differ.

The largest retained split is run A versus B: 1,038 pixels and 2,745 RGB
channels within source bounds `[777, 734, 1016, 858]`; alpha differs at zero
pixels. Run A versus C differs at five RGB pixels. The locality sheet binds the
visible frontage/contact region affected by the split.

This is the ordered first-failure stop. South and West were not rendered, East
was not normalized, and no further sampling repair is requested. The accepted
North immutable master and its normalized LODs remain unchanged.
`sourceAuthority=false` and `productionSelected=false`.
