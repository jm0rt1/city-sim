# Automated Validation Supplied by Integration

- Exact integrated master commit: `a5d1c383677c0c4b0d76f6de1d12ab978600cfa1`.
- Full native suite: **119/119 passed**, zero failures, **358.596 seconds** test time on the exact commit.
- City command/input suite: **18/18 passed**.
- Renderer changed-pulse diagnostic: **1.363 ms average**, 5,759 tile reuses and one authoritative update.
- Thirty-minute-equivalent renderer soak: 4,286 pulses, **1.1099 ms average**, 10,289 nodes, 2,505 drawables, five actions.
- Exact production staged app launched and remained alive at PID `63684`.
- Exact isolated quality bundle launched and remained alive at PID `64990`.
- `git diff --check` and `bash -n script/build_and_run.sh` passed before staging.

These results localize automated correctness and performance. Under the frozen PLAY-051 rubric they do not substitute for pointer, keyboard, FKA, VoiceOver, persistence, corruption-recovery, or replay-desire journeys.
