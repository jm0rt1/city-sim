# PLAY-063 Independent Live Results

The exact staged quality app loaded the frozen Industrial complication fixture
paused at Day 33/tick 128. After every load transient expired, keyboard or
pointer selection resolved the player-visible `Industrial, block 15, 12`
target (state coordinate 14,11). AX, HUD, Details, preview, construction, and
overlays agreed on that coordinate.

## Same-state presentation

The old accepted baseline renders block 15,12 as the generic brick
south-facing factory used for every frontage. The candidate renders the exact
accepted south-facing loading works: dark factory mass, high orange-edged
gantry, entrance/loading relationship, service apron, roof equipment, and
grounded contact shadow. The change is immediately recognizable in both the
uncropped regular and exact compact frames without altering treasury,
population, jobs, utilities, strategy, notices, pause state, target, or
fixture digest.

The exact scale routes are retained at:

- `live/regular/industrial-city-scale-0.85.png`;
- `live/regular/industrial-neighborhood-scale-0.65.png`;
- `live/regular/industrial-block-scale-0.50.png`; and
- `live/compact/industrial-block-scale-0.45-900x600.png`.

The three regular hashes differ and preserve useful city, neighborhood, and
block presentation. The packed 4 x 3 color and grayscale matrices independently
reproduced from the committed atlas show all N/E/S/W identities at all three
LODs. North/east/south/west gantry, factory, entrance, and apron arrangements
remain direction-distinct. Industrial is unambiguously distinct from the
Residential house and Commercial storefront in color and grayscale.

## Interaction and state truth

- Pointer selected exact Industrial block 15,12 and opened its matching
  Details surface.
- The map's exposed AX `Inspect Industrial at block 15, 12` action opened the
  same target and details.
- Keyboard `I` selected Industrial. Return on occupied block 15,12 retained
  the tool and target and reported:
  `Demolish the existing structure before building here. Industrial remains
  selected — choose another block.`
- Right moved the active target to valid block 16,12. Return constructed once,
  charged exactly $3,200, and exposed `Construction site, 0 percent`.
- A separate pointer route selected Industrial through Build > Zones, clicked
  block 16,12 once, and produced exactly one construction at the same
  coordinate.
- Command-Z restored treasury from $30,837 to $34,037 and removed the
  construction.
- The post-undo save and backup were both byte-identical to the original
  fixture (`7d12f458...`).
- Save, terminate, relaunch, and Command-O restored Day 33 paused, treasury
  $34,037, and the same state.
- Space changed `Day 33. Paused` to `Day 33. Running at 1x speed`; the next
  Space restored `Day 33. Paused`.
- All five overlay shortcuts completed in compact. Pollution AX added
  `Pollution overlay active` while retaining the selected coordinate and
  power/water/pollution/vitality truth.
- Regular and compact Focus City retained the exact selected block, treasury,
  priority, notices, pause state, and overlay.
- Compact Details exposed Industrial L1, 77/110 workers, connected road,
  $8/cycle upkeep, exact cause/consequence text, and the honest
  `Add power capacity` response.
- FKA traversal entered the visible HUD metrics and retained a stable focus
  loop. Escape closed Details before affecting the active map target.
- The separate compact Reduce Motion process retained the same selected
  factory, static state marks, HUD, and AX meaning.

The command guide was opened from map focus, accepted search input, exposed
spatial camera commands as unavailable while its modal held focus, and closed
with Escape without leaking a map command.

## Evidence limitation

The authentic production story fixture contains one live Industrial L1 lot,
whose authoritative frontage is south. Live regular/compact operation
therefore proves the south identity in a shipping scene. North, east, and west
are not invented live story lots: their admission is the exact committed
runtime 4 x 3 packed matrix, unique color/grayscale bytes, source/staged parity,
frontage socket and collision validators, and focused runtime save/load/undo
tests. This limitation is explicit and does not substitute the author's
conclusion for quality's independent execution or visual inspection.
