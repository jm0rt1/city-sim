# Specification: Logging Schema

## Purpose
Define structured logging for reproducibility and analysis.

## Format Options
- JSON Lines (JSONL) or CSV — prefer JSONL for nested structures.

## Fields (per tick)
- `timestamp`: ISO 8601
- `run_id`: UUID or seed + timestamp composite
- `tick_index`: int
- `budget`: float
- `revenue`: float
- `expenses`: float
- `population`: int
- `happiness`: float
- `policies_applied`: array
- `tick_duration_ms`: float
 - `traffic_avg_speed`: float
 - `traffic_congestion_index`: float
 - `traffic_throughput`: int

## Summary (end of run)
- `final_budget`, `final_population`, `avg_happiness`, `total_ticks`, `run_kpis`

## Paths
- Global logs: [output/logs/global](../../output/logs/global)
- UI logs: [output/logs/ui](../../output/logs/ui)

## Acceptance Criteria
- Machine‑readable outputs consistently populated for all ticks.
