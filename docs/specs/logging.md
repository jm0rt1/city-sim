# Specification: Logging Schema

## Purpose
Define structured logging formats, required fields, validation rules, and best practices for reproducibility and analysis. This specification ensures consistent, machine-readable outputs that enable deep analysis, debugging, and visualization of simulation behavior.

## Overview

City-Sim uses structured logging to capture complete simulation state and metrics at each tick. The logging system:

- **Enables Reproducibility**: Logs contain all information needed to understand simulation behavior
- **Supports Analysis**: Machine-readable format facilitates automated analysis and visualization
- **Aids Debugging**: Detailed per-tick information helps diagnose issues
- **Tracks Performance**: Timing metrics identify bottlenecks and regressions

## Format Options

### JSONL (JSON Lines) - Recommended

**Description**: Each line is a complete, valid JSON object representing one log entry.

**Advantages**:
- Handles nested structures naturally (e.g., applied policies, infrastructure metrics)
- Easy to parse with standard JSON libraries
- Human-readable with proper formatting
- Supports schema evolution (new fields don't break old parsers)
- Efficient streaming (process one line at a time)

**Disadvantages**:
- Slightly larger file size than CSV
- Requires JSON parser (not readable in spreadsheets without conversion)

**Example**:
```json
{"timestamp": "2024-01-15T10:30:45.123Z", "run_id": "run_001", "tick_index": 0, "budget": 1000000.0, "revenue": 0.0, "expenses": 0.0, "population": 10000, "happiness": 60.0, "policies_applied": [], "tick_duration_ms": 5.2}
{"timestamp": "2024-01-15T10:30:45.234Z", "run_id": "run_001", "tick_index": 1, "budget": 1020000.0, "revenue": 50000.0, "expenses": 30000.0, "population": 10005, "happiness": 60.5, "policies_applied": ["tax_001"], "tick_duration_ms": 6.1}
```

**When to Use**: Default choice for all new logging. Use for complex nested data and when analysis tools support JSON.

### CSV (Comma-Separated Values) - Alternative

**Description**: Tabular format with header row and data rows.

**Advantages**:
- Compact file size
- Easy to open in spreadsheets (Excel, Google Sheets)
- Simple to parse
- Wide tool support

**Disadvantages**:
- Difficult to represent nested structures (requires flattening or multiple files)
- Schema changes can break parsers
- Escaping rules for special characters (commas, quotes) can be error-prone

**Example**:
```csv
timestamp,run_id,tick_index,budget,revenue,expenses,population,happiness,tick_duration_ms
2024-01-15T10:30:45.123Z,run_001,0,1000000.0,0.0,0.0,10000,60.0,5.2
2024-01-15T10:30:45.234Z,run_001,1,1020000.0,50000.0,30000.0,10005,60.5,6.1
```

**When to Use**: When maximum compatibility with spreadsheets is needed and data is primarily flat (not nested).

**Note**: For nested data (e.g., `policies_applied`), either flatten to multiple columns (`policy_1`, `policy_2`, ...) or use JSON-encoded strings within CSV fields.

## Required Fields (Per Tick)

Every tick log entry must include these fields:

### Temporal Fields

- **`timestamp`** (string, ISO 8601): 
  - Format: `YYYY-MM-DDTHH:mm:ss.sssZ` (UTC timezone)
  - Example: `"2024-01-15T10:30:45.123Z"`
  - Purpose: Absolute time when tick completed (for correlating logs with external events)

- **`run_id`** (string):
  - Format: UUID or composite of seed + timestamp
  - Example: `"run_20240115_103045_seed_12345"` or `"550e8400-e29b-41d4-a716-446655440000"`
  - Purpose: Uniquely identify this simulation run across all logs

- **`tick_index`** (integer, >= 0):
  - The zero-based tick number
  - Example: `0`, `1`, `2`, ..., `999`
  - Purpose: Order ticks within a run; correlate with simulation state

### Financial Fields

- **`budget`** (float):
  - Current city budget/treasury balance at end of tick
  - Can be negative (representing debt)
  - Example: `1000000.0`, `-50000.0`

- **`revenue`** (float, >= 0):
  - Total revenue generated during this tick
  - Includes taxes, fees, grants
  - Example: `50000.0`

- **`expenses`** (float, >= 0):
  - Total expenses incurred during this tick
  - Includes services, infrastructure maintenance, salaries
  - Example: `30000.0`

### Population Fields

- **`population`** (integer, >= 0):
  - Total city population at end of tick
  - Example: `10000`, `10005`

- **`happiness`** (float, 0..100):
  - Aggregate happiness metric at end of tick
  - Normalized to 0-100 scale
  - Example: `60.5`, `72.3`

### Policy Fields

- **`policies_applied`** (array of strings):
  - List of policy IDs applied during this tick
  - Empty array if no policies applied
  - Example: `["tax_policy_001", "infrastructure_invest_002"]` or `[]`

### Performance Fields

- **`tick_duration_ms`** (float, >= 0):
  - Time taken to execute this tick in milliseconds
  - Measured from tick start to tick completion
  - Includes all subsystem updates and logging overhead
  - Example: `5.2`, `12.8`

### Transport/Traffic Fields (When Transport Subsystem Active)

- **`traffic_avg_speed`** (float, >= 0):
  - Average vehicle speed across all road segments (units: km/h or m/s as configured)
  - Null/omitted if no vehicles or transport not active
  - Example: `45.5` (km/h)

- **`traffic_congestion_index`** (float, 0..1):
  - Aggregate congestion metric (0 = free flow, 1 = gridlock)
  - Calculated from speed reductions and queue lengths
  - Null/omitted if transport not active
  - Example: `0.35`

- **`traffic_throughput`** (integer, >= 0):
  - Number of vehicles that completed trips this tick
  - Null/omitted if transport not active
  - Example: `150`

## Optional Fields

These fields provide additional context but are not required:

### Detailed Financial Breakdown
- `revenue_taxes`: Revenue from taxes specifically
- `revenue_fees`: Revenue from fees specifically
- `expenses_services`: Expenses for services specifically
- `expenses_infrastructure`: Infrastructure maintenance expenses

### Detailed Population Metrics
- `population_births`: New births this tick
- `population_deaths`: Deaths this tick
- `population_migration_in`: Immigration this tick
- `population_migration_out`: Emigration this tick
- `happiness_change`: Change in happiness from previous tick

### Infrastructure Quality
- `infrastructure_transport_quality`: Transport network quality (0..100)
- `infrastructure_power_quality`: Power grid quality (0..100)
- `infrastructure_water_quality`: Water system quality (0..100)

### Service Coverage
- `service_health_coverage`: Healthcare coverage (0..100)
- `service_education_coverage`: Education coverage (0..100)
- `service_safety_coverage`: Public safety coverage (0..100)
- `service_housing_coverage`: Housing coverage (0..100)

### Detailed Traffic Metrics
- `traffic_total_vehicles`: Total active vehicles
- `traffic_incidents`: Number of traffic incidents this tick
- `traffic_signal_changes`: Number of signal state changes
- `traffic_reroutes`: Number of vehicles that rerouted

### Performance Profiling
- `tick_duration_finance_ms`: Time spent in finance subsystem
- `tick_duration_population_ms`: Time spent in population subsystem
- `tick_duration_transport_ms`: Time spent in transport subsystem
- `tick_duration_logging_ms`: Time spent writing logs

## Run Summary (End of Run)

After all ticks complete, write a summary entry with aggregated results:

### Required Summary Fields

- **`run_id`** (string): Same as tick logs
- **`summary`** (boolean): `true` to distinguish from tick logs
- **`final_budget`** (float): Budget at final tick
- **`final_population`** (integer): Population at final tick
- **`avg_happiness`** (float): Mean happiness across all ticks
- **`total_ticks`** (integer): Number of ticks executed
- **`run_duration_ms`** (float): Total wall-clock time for run
- **`run_kpis`** (object): Key performance indicators, e.g.:
  - `avg_revenue`: Mean revenue per tick
  - `avg_expenses`: Mean expenses per tick
  - `avg_population_growth`: Mean population change per tick
  - `peak_congestion`: Maximum congestion index observed

### Example Summary Entry (JSONL)

```json
{
  "run_id": "run_001",
  "summary": true,
  "final_budget": 1500000.0,
  "final_population": 12500,
  "avg_happiness": 65.3,
  "total_ticks": 1000,
  "run_duration_ms": 5432.1,
  "run_kpis": {
    "avg_revenue": 52000.0,
    "avg_expenses": 31000.0,
    "avg_population_growth": 2.5,
    "peak_congestion": 0.78,
    "budget_surplus": 500000.0
  }
}
```

## File Paths & Organization

### Directory Structure

```
output/
├── logs/
│   ├── global/                 # Global simulation logs
│   │   ├── run_001.jsonl
│   │   ├── run_002.jsonl
│   │   └── ...
│   └── ui/                     # UI-specific logs (if applicable)
│       ├── ui_events_001.jsonl
│       └── ...
└── reports/                    # Human-readable reports
    ├── run_001_summary.txt
    ├── run_002_summary.txt
    └── ...
```

### File Naming Conventions

- **Tick Logs**: `{run_id}.jsonl` or `{run_id}.csv`
  - Example: `run_20240115_103045_seed_12345.jsonl`
  
- **Summary Reports**: `{run_id}_summary.txt` or `{run_id}_summary.json`
  - Example: `run_001_summary.txt`

- **Archived Logs**: Include timestamp in subdirectories for organization
  - Example: `output/logs/global/2024-01-15/run_001.jsonl`

### File Locations

- **Global Logs**: [output/logs/global](../../output/logs/global)
  - Contains logs for all simulation runs executed via CLI or batch mode

- **UI Logs**: [output/logs/ui](../../output/logs/ui)
  - Contains UI-specific event logs (user interactions, visualization events)
  - Separate from simulation logs to avoid mixing concerns

## Schema Validation

### Validation Rules

Implement validation to ensure log quality:

1. **Required Fields Present**: All required fields must be present in every log entry
2. **Type Correctness**: Fields must match declared types (int, float, string, array)
3. **Range Constraints**: Bounded fields (happiness, quality metrics) must be in valid ranges
4. **Invariant Checks**: Budget reconciliation equation must hold (within tolerance)
5. **Monotonic Tick Index**: Tick indices must increase by exactly 1

### Example Validation Logic (Pseudocode)

```python
def validate_log_entry(entry: Dict, previous_entry: Optional[Dict]) -> List[str]:
    """
    Validate a single log entry.
    
    Returns:
        List of validation errors (empty if valid)
    """
    errors = []
    
    # Check required fields
    required = ["timestamp", "run_id", "tick_index", "budget", "revenue", 
                "expenses", "population", "happiness", "policies_applied", 
                "tick_duration_ms"]
    for field in required:
        if field not in entry:
            errors.append(f"Missing required field: {field}")
    
    # Check types
    if not isinstance(entry.get("tick_index"), int):
        errors.append("tick_index must be integer")
    if not isinstance(entry.get("population"), int):
        errors.append("population must be integer")
    
    # Check ranges
    if not (0 <= entry.get("happiness", -1) <= 100):
        errors.append("happiness must be in range [0, 100]")
    if entry.get("population", -1) < 0:
        errors.append("population must be non-negative")
    
    # Check budget reconciliation
    if previous_entry:
        expected_budget = (previous_entry["budget"] + 
                          entry["revenue"] - entry["expenses"])
        if abs(entry["budget"] - expected_budget) > 1e-6:
            errors.append(f"Budget reconciliation failed: expected {expected_budget}, "
                         f"got {entry['budget']}")
    
    # Check tick monotonicity
    if previous_entry:
        if entry["tick_index"] != previous_entry["tick_index"] + 1:
            errors.append(f"Tick index not sequential: previous {previous_entry['tick_index']}, "
                         f"current {entry['tick_index']}")
    
    return errors
```

### Validation Modes

- **Strict Mode** (Development): Raise exception on first validation error
- **Logging Mode** (Production): Log validation errors but continue execution
- **Offline Mode**: Validate log files after simulation completes

## Usage Examples

### Example 1: Writing a Tick Log Entry (Python, JSONL)

```python
import json
from datetime import datetime

def log_tick(logger, run_id: str, tick_index: int, city: City, 
             delta: CityDelta, tick_duration_ms: float):
    """Write a single tick log entry."""
    
    entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "run_id": run_id,
        "tick_index": tick_index,
        "budget": city.state.budget,
        "revenue": delta.revenue,
        "expenses": delta.expenses,
        "population": city.state.population,
        "happiness": city.state.happiness,
        "policies_applied": [d.decision_id for d in delta.applied_decisions],
        "tick_duration_ms": tick_duration_ms,
        
        # Optional traffic fields (if available)
        "traffic_avg_speed": delta.traffic_avg_speed if delta.traffic_delta else None,
        "traffic_congestion_index": delta.traffic_congestion_index if delta.traffic_delta else None,
        "traffic_throughput": delta.traffic_throughput if delta.traffic_delta else None,
    }
    
    # Remove None values to keep logs clean
    entry = {k: v for k, v in entry.items() if v is not None}
    
    # Write JSON line
    logger.write(json.dumps(entry) + "\n")
```

### Example 2: Reading and Analyzing Logs (Python)

```python
import json

def analyze_run(log_file: str):
    """Analyze a simulation run from its log file."""
    
    ticks = []
    
    with open(log_file, 'r') as f:
        for line in f:
            entry = json.loads(line)
            if not entry.get("summary", False):
                ticks.append(entry)
    
    # Calculate statistics
    avg_revenue = sum(t["revenue"] for t in ticks) / len(ticks)
    avg_expenses = sum(t["expenses"] for t in ticks) / len(ticks)
    final_population = ticks[-1]["population"]
    
    print(f"Ticks: {len(ticks)}")
    print(f"Avg Revenue: ${avg_revenue:,.2f}")
    print(f"Avg Expenses: ${avg_expenses:,.2f}")
    print(f"Final Population: {final_population:,}")
    
    # Check budget reconciliation across all ticks
    for i in range(1, len(ticks)):
        expected = ticks[i-1]["budget"] + ticks[i]["revenue"] - ticks[i]["expenses"]
        actual = ticks[i]["budget"]
        if abs(expected - actual) > 1e-6:
            print(f"WARNING: Budget mismatch at tick {ticks[i]['tick_index']}")
```

### Example 3: Exporting Logs to DataFrame (Python, Pandas)

```python
import pandas as pd
import json

def logs_to_dataframe(log_file: str) -> pd.DataFrame:
    """Convert JSONL log file to Pandas DataFrame for analysis."""
    
    entries = []
    with open(log_file, 'r') as f:
        for line in f:
            entry = json.loads(line)
            if not entry.get("summary", False):
                entries.append(entry)
    
    df = pd.DataFrame(entries)
    
    # Convert timestamp to datetime
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    
    # Add computed columns
    df['net_revenue'] = df['revenue'] - df['expenses']
    df['population_pct_change'] = df['population'].pct_change() * 100
    
    return df

# Usage
df = logs_to_dataframe("output/logs/global/run_001.jsonl")
print(df[['tick_index', 'budget', 'population', 'happiness']].head())
```

## Performance Considerations

### Logging Overhead

- **Target**: Logging should consume < 5% of tick duration
- **Buffering**: Buffer log entries in memory and flush periodically (e.g., every 100 ticks)
- **Async Writing**: Consider async I/O for log writing to avoid blocking simulation
- **Profiling**: Include `tick_duration_logging_ms` to track logging overhead

### File Size Management

- **Compression**: Consider gzip compression for archived logs (`.jsonl.gz`)
- **Rotation**: Rotate logs by size or time to prevent huge files
- **Sampling**: For very long runs (10,000+ ticks), consider sampling (log every Nth tick)

### Efficient Parsing

- **Streaming**: Process JSONL files line-by-line to avoid loading entire file into memory
- **Indexing**: For large files, create index file mapping tick_index to byte offset for random access

## Best Practices

1. **Always Include Run ID**: Enables correlating logs across restarts or parallel runs
2. **Use ISO 8601 Timestamps**: Ensures unambiguous time representation across timezones
3. **Validate Early**: Check log schema during development to catch errors quickly
4. **Document Schema Changes**: When adding fields, document in ADR and update this spec
5. **Provide Examples**: Include sample log files in repository for reference
6. **Test with Analysis Tools**: Verify logs work with intended analysis tools (Pandas, Jupyter, etc.)
7. **Separate Concerns**: Keep simulation logs separate from UI/debug logs

## Acceptance Criteria

A compliant logging implementation must:

1. **Consistently Populate Required Fields**: All required fields present in every tick log entry
2. **Maintain Schema Compliance**: Logs pass schema validation without errors
3. **Enable Reproducibility**: Logs contain sufficient information to understand simulation behavior
4. **Support Analysis**: Logs can be parsed and analyzed with standard tools (Python, R, spreadsheets)
5. **Perform Efficiently**: Logging overhead < 5% of tick duration
6. **Handle Edge Cases**: Correctly log edge cases (zero population, negative budget, empty policies)

## Testing Strategy

### Unit Tests
- Test log entry generation for single tick
- Validate schema compliance
- Test handling of None/null values
- Test field type conversions

### Integration Tests
- Run multi-tick scenario and validate log file
- Verify budget reconciliation across all ticks
- Check tick monotonicity
- Test summary generation

### Performance Tests
- Measure logging overhead as % of tick duration
- Verify performance target (< 5%)
- Test with various tick durations and data volumes

## Future Enhancements

### Planned Features
- **Structured Events**: Separate event log for discrete occurrences (policy changes, incidents)
- **Binary Format**: Protobuf or similar for maximum performance
- **Streaming API**: Real-time log streaming for live dashboards
- **Log Aggregation**: Automatic aggregation of metrics over time windows
- **Compression**: Automatic compression of older log files

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: Logging component description
- **[City Specification](city.md)**: City state fields logged each tick
- **[Finance Specification](finance.md)**: Financial fields in logs
- **[Population Specification](population.md)**: Population fields in logs
- **[Traffic Specification](traffic.md)**: Traffic fields in logs
- **[Glossary](../guides/glossary.md)**: Term definitions for log fields
