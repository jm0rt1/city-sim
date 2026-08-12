# UI and Input Execution and Evidence

Read this reference when implementing, validating, or completing a UI/input packet.

## Implement and prove

1. Add store/command/focus tests alongside behavior.
2. Run the focused owner and directly affected gates named in the validated `modelRoute`, plus `git diff --check`; the lane coordinator runs the complete Swift suite only at the exact aggregate boundary.
3. Build and operate the staged app using mouse/trackpad and keyboard-only flows at the exact aggregate candidate boundary rather than once per unchanged execution packet.
4. Test text-entry suppression, Escape priority, destructive targeting, focus stability, and Reduce Motion.
5. Capture real default and compact proof for every changed surface.
6. Check HUD terminology and denominators against simulation analytics.
7. Report VoiceOver and Full Keyboard Access separately.
8. If the route can change a player-visible view, consume its immutable
   `composed_screen_contract`. The aggregate gate—not the worker focused gate—
   compares the frozen predecessor and exact candidate with the same fixture,
   camera, regular/900x600 geometry, and command. A local UI PASS may not claim
   that map aperture, guidance exclusivity, or whole-screen hierarchy improved.

## Completion

Commit focused work and write the completion record with automated and hands-on evidence. Do not push or merge. A control that exists but is not discoverable, keyboard-operable, accessible, or proven in compact layout is incomplete.
