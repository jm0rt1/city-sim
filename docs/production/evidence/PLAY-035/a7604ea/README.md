# PLAY-035 staged evidence — `a7604ea`

## Candidate

- Product commit: `a7604eafcaa042583270bc4f9da07d254d5b8af1`
- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Default frame: 1,229 x 768 on the host display
- Explicit compact frame: 900 x 652 for exact 900 x 600 content

## Default keyboard journey

The staged city was paused, Commercial was selected by `C`, and Right selected occupied Road block 14,13. Before activation, the map accessibility value truthfully announced `Unavailable. Demolish the existing structure before building here.` and exposed no unavailable build custom action.

Return produced `Action blocked` with `Demolish the existing structure before building here. Commercial remains selected — choose another block.` After an explicit four-second wait, the message remained visible and accessible; the city stayed paused, treasury stayed `$25,432`, Road block 14,13 remained selected, Build/Commercial remained selected, and Undo stayed unavailable.

Moving Right then Down selected available Open Land block 15,14. Return built Commercial exactly once: treasury moved from `$25,432` to `$23,032`, the selected tile became Commercial, the store reported `Commercial construction approved`, and Undo became available.

## Compact keyboard journey

The same product commit was relaunched with `CITYSIM_COMPACT_WINDOW=1`. Space paused, `C` selected Commercial, and Right selected occupied Road block 14,13. Return produced the same exact durable rejection. After four seconds, the 900 x 600 content retained map focus, selected coordinate, Commercial tool, truthful unavailable disclosure, `Action blocked`, and disabled Undo. Escape then returned to Inspect, cleared the coordinate, and reported `Action cancelled` through the existing cancellation route.

## Retained captures

- `default-return-rejection-after-4s.jpeg` — default durable rejected Return, 1,229 x 768.
- `default-valid-return.jpeg` — default successful Return after exactly one $2,400 Commercial build, 1,229 x 768.
- `compact-return-rejection-after-4s.jpeg` — exact compact durable rejected Return, 900 x 652 frame / 900 x 600 content.

AX inspection and keyboard operation were performed separately from spoken VoiceOver; spoken VoiceOver is not claimed. No save action was invoked because the repair changes only transient command routing and feedback.
