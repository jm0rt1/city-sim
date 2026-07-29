# PLAY-080 source-candidate packet writer boundary

This task-owned boundary reserves no new authority. It binds the immutable
Integration locator schema and instance published at
`fa66b5605deca987685c058a072613e89a0d8be9` and permits only:

```text
docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/SOURCE-STAGE-HANDOFF-V2.json
```

The default is dry-run. A future `--write` invocation remains blocked unless
all of these gates pass first:

1. the locator schema and instance have their exact published SHA-256 values,
   validate together, and remain byte-identical at the publication commit;
2. the candidate binds the exact PLAY-080 South task, branch, roots, reserved
   path, and committed content ancestor;
3. the Integration-owned source-stage-v2 semantic validator passes a private
   validation copy made only from the writer's already captured candidate
   bytes;
4. the task-owned strict parallel-receipt validator passes bytes read through
   a nofollow descriptor at the exact reserved South receipt path; and
5. every existing destination component is a real directory, the final path
   is absent, and the eventual create uses an opened parent directory plus
   `O_CREAT|O_EXCL|O_NOFOLLOW`.

The CLI emits only to stdout. It never writes a rejection report and it never
creates parent directories. The present checkpoint uses injected
nonproduction validation results only inside the focused test harness; those
results cannot reach the `--write` CLI path.

Run the structural suite without bytecode or pixels:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/test_source_candidate_packet_writer.py
```

Do not invoke `--write` until post-lock production has produced and committed
the complete South source-stage-v2 artifact set and strict execution receipt.
