# Industrial L4 East Dynamic Live-Identity Return Repair v1

**Owner:** Integration frontier authority

**Task:** PLAY-079 East

## Disposition

Candidate `e9f3d89080317b0183ad3d644ac4463bfb8c148a` is preserved and returned.
It introduced a structurally correct Git identity resolver, but its immutable
contract and positive fixtures still bind parent `f2672462...`; the exact
candidate therefore rejects its own live checkout. This is the second failed
bounded repair and must not receive another Luna attempt.

## Required reference repair

Use `FRONTIER_AUTHORITY / gpt-5.6-sol / high`. Preserve the accepted portal
material assignment and all historical bytes. Within East-owned closure and
test paths only:

1. Treat task-owned `observedHead` as provenance, never runtime authorization.
2. Resolve live branch and `git rev-parse HEAD` dynamically at validation time.
3. Compare that live identity to external Integration-authored schedule,
   grant, session and profile documents whose hashes and cross-links are
   validated after the coherent candidate commit exists.
4. Do not hardcode or synthesize the candidate's future commit SHA inside the
   commit that creates it.
5. Build positive fixtures with separate worker and Integration-authority Git
   repositories: freeze the worker HEAD first, then commit external authority
   documents that bind it.
6. Reject stale parent, missing/mismatched HEAD or branch, wrong claim/route,
   inline or caller-controlled authority, forged hashes and cross-document
   drift before any child/output effect.

The repair turn is zero-DCC and returns executableBehavior=UNPROVEN. A later
Integration packet will bind the exact accepted candidate and independently
exercise the closure before any source launch.
