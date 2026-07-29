# PLAY-075 candidate-neutral fixture materializer

This preparation tool validates a fully explicit renderer-candidate and
four-packet identity request, then emits only a deterministic plan receipt. It
does not create a completed, construction, or condition save; build, stage, or
run the app; inspect product implementation; or declare QA disposition.

The exact immutable input fixture is fixed at SHA-256
`b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.
The request has no mutable CLI or JSON defaults. It must name:

- one exact clean renderer commit, the identical admitted commit, and the
  exact admission-authority commit;
- four unique packets in canonical North/East/South/West order, each with a
  unique commit and hash bound to that renderer commit;
- the accepted bridge authority and mapping hash;
- runtime-cardinal labels and exact source-pixel sockets; and
- explicit false values for aliases, fallbacks, DCC labels, and
  per-direction transforms.

One through three directions, stale or placeholder candidate identities,
unbound hashes, wrong sockets, aliases/fallbacks, DCC labels, transforms,
schema drift, frozen-fixture drift, and outputs outside
`docs/production/evidence/PLAY-075/` fail before any receipt is written.

`contract-rehearsal-request.json` uses conspicuously synthetic immutable
identities and mode `contract_rehearsal`. Its receipt proves only deterministic
tool behavior. It is not a candidate, fixture, art, renderer, app, or QA
acceptance record.

Run the preparation proof with four caller-supplied task-owned output roots:

```bash
python3 -B tools/validate_fixture_materializer.py \
  --request fixture-materializer/contract-rehearsal-request.json \
  --run-a-output-root fixture-materializer/proof/run-a \
  --run-b-output-root fixture-materializer/proof/run-b \
  --report-output-root fixture-materializer/proof
```

For a future Integration-admitted exact candidate, use
`tools/materialize_fixture_receipt.py` with a request conforming to
`REQUEST-FORMAT.json`, mode `candidate_bound`, and an explicit output root
beneath the PLAY-075 evidence tree. The resulting receipt describes the three
candidate-bound derivative plans and expected capture tree, but still creates
no save or acceptance fixture.
