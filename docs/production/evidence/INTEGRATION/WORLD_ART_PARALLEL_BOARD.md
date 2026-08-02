# World Art Parallel Board — appearance lock pending

| Cell | Current state | Dispatch | Branch / claim | Head | Blocker |
|---|---|---|---|---|---|
| North | predesign | completed | codex/citysim-world-art / PLAY-027 | 5657b8a37a96c70e608585515dc059519ceff435 | exact current v13 zero-pixel replay and Integration-direct North-A schedule are not yet published |
| East | predesign | completed | codex/citysim-world-art-east / PLAY-079 | 6a8c61a76802b13eb1704671cf63f4323052a67f | technically approved; pixels wait for North appearance lock and postlock grants |
| South | predesign | completed | codex/citysim-world-art-south / PLAY-080 | 84630b927a94c1e7324fc5e9ebe6acf337d64dd5 | technically approved; pixels wait for North appearance lock and postlock grants |
| West | predesign | completed | codex/citysim-world-art-west / PLAY-081 | 6499fec5181bbf8712e20ce147a35b4a2b736317 | technically approved; pixels wait for North appearance lock and postlock grants |
| Renderer | intake_ready | completed | codex/citysim-world-rendering-r4b-current / PLAY-073 | 66650f142960920e3d886a1da7e39857bd195768 | quarantine waits for exact Integration source-admission receipts |
| QA | preregistering | blocked | codex/citysim-playtest-quality / PLAY-075 | 43e3e57afb52480d90bcf4b08d610ac5950e34bd | worktree is reserved by an unconsumed exact-candidate QA lease; no Industrial L4 renderer candidate exists |

No row is represented as active. North replay inventory is running in the
separate low-cost PLAY-089 observer lane; it does not count as a family cell.
East, South, and West technical dispositions are preserved independently and
will not be demoted while North advances.
