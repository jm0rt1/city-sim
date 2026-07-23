# PLAY-036 staged evidence — `878114e`

## Candidate

- Product commit: `878114e2fde2be18bad88b1b53294cafb19e18e8`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Fresh default frame: 1,229 x 768 on the host display
- Explicit compact frame: 900 x 652 for exact 900 x 600 content

The isolated candidate preference domain was cleared before the default launch. The staged app opened at the intended default size with Welcome visible and only `welcome.start-building` exposed from the game surface. After explicit dismissal, the authored city was still Day 1 at 1x. The city was then paused before command-guide activation proof.

## Search and activation journeys

Fresh guide openings focused an empty search field. Each of `tax`, `budget`, and `storefront` produced one result: `Open Tax Policy and Finances`, announced as available with shortcut `⌥2` and the existing command description.

- **Pointer:** a coordinate click on the visible `tax` result closed the guide and exposed Command Center > Finances at the unchanged 10% tax rate.
- **Return:** with `budget` entered and search focus retained, Return activated the sole result, closed the guide, exposed Finances, and returned focus to the map.
- **Space:** with `storefront` entered, two Tabs focused the actual result button. Space activated it, closed the guide, exposed Finances, and returned focus to the map.
- **Accessibility action:** the accessible Press action on the available `budget` result activated the same store intent, closed the guide, exposed Finances, and returned focus to the map.

The first fresh `Undo Construction` search remained a disabled button with `There is no reversible construction action`. Return and an attempted accessibility Press left the guide open, preserved the exact disabled reason, and did not expose or mutate a construction action. Escape then closed the guide, restored map focus, and reopening showed an empty focused query rather than the prior `undo` text.

The product commit was relaunched with `CITYSIM_COMPACT_WINDOW=1`. The host capture measured a 900 x 652 frame / 900 x 600 content. `storefront` again produced the single available Tax Policy result; Return closed the guide into the scrollable compact Finances deck while the map remained present.

## Retained captures

- `default-fresh-welcome-1229x768.jpg` — genuine fresh default launch and modal accessibility containment.
- `default-tax-search.jpg` — the sole truthful Tax Policy result for `tax`.
- `default-pointer-finances-1229x768.jpg` — pointer activation closed the guide and exposed default Finances.
- `compact-storefront-search.jpg` — the sole result for `storefront` in the compact sheet.
- `compact-return-finances-900x652-frame.jpg` — Return activation exposed compact Finances at exact 900 x 600 content.

AX inspection and keyboard operation were performed separately from spoken VoiceOver; spoken VoiceOver is not claimed. The test did not adjust tax, build, save, or load, so simulation and session truth were not changed by the remedy route.
