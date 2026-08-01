# Industrial L4 Integration-direct launch authority v1

**Owner:** Integration

**Status:** active replacement authority

**Batch:** `industrial_l04_directional_family`

**Execution mode:** `integration_direct`

## Decision

Retire the North v13 `process-a-prelaunch-v01` repair lineage without
integration. Exact candidate `40be307ee2490dca072f0ff086d6b1a13a6a9fee`
remains preserved on `codex/citysim-world-art` as rejected evidence. No R5 is
authorized.

The rejected design attempted to authenticate an imported Python caller while
also exposing a public authority builder that accepted the caller's signing
key. Independent review correctly proved that this is not an authentication
boundary. Further patches to that lineage would spend frontier time defending
an in-process secret that does not exist.

For North v13 Process A, Integration now owns the launch itself. The World Art
cell may implement and zero-child test one new high-level orchestrator under a
new `process-a-v02` root. It may not run Blender, render, normalize, create
pixels, consume a schedule attempt, or claim launch readiness. After that
orchestrator is independently accepted and bound by hash, Integration will
publish the exact prelock schedule and invoke it once from the governed North
worktree. Integration's process receipt—not a worker-authored token—will prove
the command, branch, HEAD, claim, slot, roots, PID, timestamps, and exactly-one
child start.

## Frozen inputs

- claim `docs/production/claims/PLAY-027.world-art.md` —
  `7d42ba7c38a55d7681171499aad50e15c2d3eba0878cabf508d0e42ee97cdc83`
- design scene —
  `0f7a8e40a07f5c2b7320ab42fe5e1bcb2dc23fb508ff6b04e8ea49cf6c974060`
- design materials —
  `c8179b77a184e41b723e26b34e7da2ef256b09e93b54a47e76cc5103f22b8cab`
- design authority —
  `1b1006403081c3933c54451b6c506af74493a2ac3b253fdd9f1f79098d7c1bed`
- lowering contract —
  `41125b2ee110085451a787879825cefe9a724cafa8ed3347db5a2688b063e111`
- lowering authority —
  `bf95dc1ba2947d9a1ede7d3ce41facacb20e2460c20ed3567abd9d8d9454ebe6`

## Worker boundary

The new orchestrator must:

1. consume the frozen North v13 scene, materials, lowering contract, and the
   later schedule path as explicit CLI inputs;
2. validate repository root, branch, HEAD, claim, direction `north`, process
   `A`, slot, exact hashes, and exclusive output/evidence roots before child
   construction;
3. expose no authority builder, signer, secret, token factory, or worker-side
   attempt consumer;
4. keep the low-level Blender child non-invocable except through the
   high-level orchestrator;
5. support a zero-child validation mode that writes only task-owned evidence;
6. fail closed on a missing Integration process receipt path; and
7. leave the actual receipt and attempt marker unwritten until Integration's
   later direct launch.

The implementation packet is Luna-eligible because the architecture and
security boundary are frozen here. Any need to change the family design,
schedule schema, shared validator, product art direction, or pixel disposition
returns to Integration.

## Integration launch boundary

After independent acceptance, Integration will publish a new prelock schedule
binding the exact orchestrator hash and one DCC slot. Integration will then:

1. prove a clean North branch at the exact accepted orchestrator commit;
2. validate the schedule with the family validator;
3. create an exclusive attempt marker and process receipt in an
   Integration-owned isolated root;
4. invoke exactly one high-level North Process A command;
5. record PID, command hash, environment/toolchain identity, start/end,
   outputs, and exit status; and
6. return the closed raw output to North for provenance, deterministic review,
   and independent frontier visual judgment.

This authority grants no B/C process, sibling pixels, appearance lock, source
admission, production selection, renderer activation, integration, or push.
