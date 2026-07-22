# Exact staged live evidence — `fc8b838`

All files in this directory come from the staged app at product commit
`fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`, candidate ID
`world-rendering-w5f893ad1da1b`, bundle/preference domain
`com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`.

## Composition and LOD

- `default-shipping-paused.jpeg` and `compact-900x600-shipping-paused.jpeg`
  are uncropped app-window captures.
- Default and compact `city`, `neighborhood`, and `block` files retain the
  same paused state at distinct semantic LODs.
- Default pointer selection announces City Hall `(12, 12)`; default keyboard
  movement announces Road `(14, 13)`. Matching accessibility trees are retained.
- Compact proof retains the same pointer/keyboard coordinates plus valid
  Residential `(16, 14)`, invalid no-road `(15, 15)`, commit, undo, overlay,
  save/load, and Reduce Motion A/B.

## Construction

`construction-{00,25,50,75,100}-residential-16-14.jpeg` records one real staged
Residential at the same coordinate. The app was paused between single normal
simulation pulses, and every screenshot has matching retained accessibility
text. `construction-undo-residential-16-14.jpeg` returns the authoritative
state to open land.

## Pan and zoom

`default-pan-zoom-live-7fps.mov` contains 42 actual Computer Use captures from
one app-only pan/zoom journey. The source capture elapsed 21,117 ms; frames are
encoded at 7 fps without generated in-between imagery. The JSON records source
timestamps and the contact sheet makes the LOD transitions reviewable.

## Accessibility and Reduce Motion

The retained accessibility trees verify that visible selection, placement,
construction stage, and overlay state agree with the app's announced map
target. Automated diagnostics report two normal ambient actions and zero
actions with Reduce Motion. Compact A/B screenshots retain the static meaning.

## Memory

Exact staged physical-footprint samples were taken after three LOD cycles and
a 60-second settle:

- compact 900 x 600: 236 MB physical footprint, 102,896 KiB RSS;
- regular 1278 x 768: 300 MB physical footprint, 274,768 KiB RSS.

Both settled footprints are below the 333.8 MiB ceiling. Peak values remain in
the unabridged reports. RSS is retained separately and is not used as a
substitute for physical footprint.

## Limits

This packet does not self-score visual quality. Default invalid placement,
default Reduce Motion A/B, and compact construction stages were not fabricated
when exact source frames were unavailable; the supporting sheet labels only
the exact live sources it consumes. CONTRACT-008 active targeting remains out
of scope and unchanged.
