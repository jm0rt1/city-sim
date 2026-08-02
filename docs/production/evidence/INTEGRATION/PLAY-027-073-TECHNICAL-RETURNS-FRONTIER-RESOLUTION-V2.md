# PLAY-027 / PLAY-073 Technical Returns — Frontier Resolution V2

**Authority:** `4594601f6261293703293e1d486151a098277e02`

## PLAY-073 renderer identity boundary

The proof compares realized SpriteKit/AppKit color, not constructor-space
inputs. Construct the adversarial pair directly in device RGB with red
components `0.25` and `0.2500002`, identical green/blue/alpha components, and
assert both prerequisites before testing the new signature:

1. the retired six-decimal realized-color signature aliases the pair; and
2. exact realized device-RGB red-component bit patterns differ.

The production proof signature remains exact realized device-RGB RGBA bit
patterns plus lossless path scalar bit patterns. Calibrated-color construction
is not authorized for this adversary because color-space conversion expands the
chosen delta beyond the retired six-decimal alias boundary.

## PLAY-027 North current-HEAD boundary

The launcher must audit worker mutation from the exact Integration-authorized
starting HEAD, not from an older design/execution ancestor that predates clean
master synchronization. For this repair that starting HEAD is
`d25d7a2767d92a8628849ca3911d28f4203dd674`.

The runner and its immutable contracts must bind that exact worker base. The
unmodified production `_changed_paths` implementation must diff that base to
the live HEAD and include untracked files. The focused test must not monkeypatch
or replace production path discovery for the real checkout; it must call the
unmodified preflight on the exact candidate HEAD and prove that only the closed
task-owned path set is admitted. Temporary adversarial repositories may use
their own explicit fixture setup, but may not alter the behavior being proven
for the real candidate.

Both returns are implementation-only under these frozen decisions. Neither
worker may launch Blender, produce pixels, mutate shipping/runtime surfaces,
run final QA, self-accept, integrate, or push.
