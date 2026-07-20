# PLAY-050 D001 and D002 Retest — d947b7d

## D001 blocking onboarding containment — passed

At default size and explicit compact size, PLAY-050 attempted `Space`, `1`, `2`, `3`, `B`, `V`, `Escape`, and `Command-/`, followed by pointer attempts against the visible underlying speed controls, command deck, and map.

- The Welcome surface remained the only game-content accessibility surface, with only `welcome.start-building` actionable.
- Underlying HUD, toolbar, SpriteKit map, command guide, selected tool, overlay, and camera did not change.
- Visible authored state remained Day 1, treasury $26,000, population 300, and 1x.
- Default remained unchanged from launch through 129 seconds.
- Compact remained unchanged through 60 seconds.
- `Return` dismissed Welcome in the default run.
- Pointer activation of `welcome.start-building` dismissed Welcome in compact.

Evidence: `d001-default-start.jpeg`, `d001-default-after-129s.jpeg`, `d001-default-dismissed-commands.jpeg`, `d001-compact-start.jpeg`, and `d001-compact-after-60s.jpeg`.

## D002 compact simultaneous surfaces — passed for the executed route

At explicit compact size, global routes opened Objectives and Command Center together. Objectives arbitrated to a compact summary that explicitly said to close details to expand all objectives. Command Center exposed `hud.command.details.scroll`, the first content, and `AXScrollToBottom`; the bottom action moved the scroll value from 0 to 1 without clipping the window or losing close/data controls.

Evidence: `d002-compact-surfaces-top.jpeg` and `d002-compact-surfaces-bottom.jpeg`.

Full Keyboard Access, VoiceOver, Reduce Motion, default-to-compact resize, and later lifecycle variants were not credited after D006 rejected the candidate.
