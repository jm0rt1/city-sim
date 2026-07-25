# Rejected LOD control attempts

These files preserve the first regular-window LOD-control attempt against
product `f06047bf74363bd7dae423cc8954776d7cb15f9d`. They are not acceptance
evidence.

The initial Computer Use sequence sent the xdotool `equal` key name. CitySim
did not interpret that input as its renderer-scoped `=` shortcut, so several
frames retained the same camera scale despite different filenames. The
attempts are retained here instead of being silently discarded.

The accepted live LOD proof in `../live/` uses:

- `minus` for one real zoom-out from Frame Developed City;
- `0` for the deterministic developed-city frame;
- typed `=` for one real zoom-in.

The resulting city, neighborhood, and block screenshots have distinct hashes,
visibly distinct framing, and matching full AX trees at both regular and exact
compact sizes.
