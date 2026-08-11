# PLAY-076 Exact-Candidate QA Claim

- **Title:** Prove a new region opens paused on Day 1 and advances to Day 11
- **Lane:** Playtest quality
- **Owner:** Agent 004 QA, thread `019fe8f2-43ac-7700-9eaf-e137c4c5ecb4`
- **Branch:** `codex/citysim-playtest-play076-current0ec1`
- **Worktree:** `/private/tmp/citysim-play076-qa-current0ec1`
- **Authority product:** `e6d359c6306d26aeb0e4d0b6af2836064e710bb5`, tree `e9e700cb0544bbce58c4a8fb20f947f767e4d4ff`
- **Staged app:** `/private/tmp/CITYSIM-PLAY076-E6D3-STAGE/CitySim.app`; executable SHA-256 `cca5dc02a942b2c3a32e4f0d5b2993f868b930cebd5da8d1085415af983f33f8`; stage manifest SHA-256 `7577ae2a4189cad6243f71490d21b254a4156e23c4999ceccc245c2389aa0091`; app/resource digests `6bdd1278b2aac68e8da318c41d15c346db7c41f08905998a12b212d26e66ee7f` / `4e7bca33f71aba3991575861a3105a2840053637170b0099576d40253b9fab11` using the route-bound deterministic commands.
- **Exclusive roots:** `/private/tmp/CITYSIM-PLAY076-E6D3-QA-V3-OUTPUT` and `/private/tmp/CITYSIM-PLAY076-E6D3-QA-V3-DATA`, both initially absent.
- **Claim-owned durable root:** `docs/production/evidence/PLAY-076/currente6d3` remains unwritten; the exclusive temp output is the only QA evidence destination in this journey.
- **Journey:** Rehash the exact staged app, revalidate PID `76765` to its exact historical executable, send at most one SIGTERM to that PID only, verify it absent, then launch the exact new staged app once with the exclusive data root. Dismiss the welcome surface if presented. Invoke File → New Region once and require the first observable region frame to be tick 0, `Day 1`, and `Paused`; capture regular and exact 900×600 views. Invoke Resume once and require normal `1×`, advance visibly to exact Day 11, pause, and capture regular and exact 900×600 views. Preserve starter-town topology, truthful controls, map aperture, and accessibility state.
- **Disposition:** `APPROVE_PLAY076_DAY1_DAY11` or the first exact `RETURN`, leaving the exact candidate process running and paused on PASS.
- **Frozen:** Product/build/repository bytes, prior V1/V2 returns, protected dirt, and every process other than exact PID `76765` at the pre-launch handoff. No retry, rebuild, test, edit, cleanup, push, release, requirement weakening, or process wildcard.
- **Status:** `active`
