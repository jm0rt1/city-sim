# ADR 002: Adoption of Free-Threaded Python 3.13+

## Status
Proposed

## Context

City-Sim is a complex simulation system with multiple interacting subsystems (environment, population, transportation, healthcare, education, emergency services, etc.). As the simulation grows in complexity and scale, performance optimization becomes increasingly critical. Python 3.13 introduces free-threaded mode (also known as "no-GIL" mode) which removes the Global Interpreter Lock (GIL), enabling true parallel execution of Python threads on multiple CPU cores.

### Current Limitations with GIL
- **Single-Core Bottleneck**: Traditional Python execution is limited to one thread at a time due to the GIL
- **Subsystem Independence**: Many of our subsystems can operate independently during a tick and would benefit from parallel execution
- **Scalability**: Large cities with extensive infrastructure require significant computational resources
- **Real-Time Requirements**: Future interactive modes may require faster-than-realtime execution

### Free-Threaded Python Benefits
- **True Parallelism**: Multiple threads can execute Python code simultaneously on different CPU cores
- **Subsystem Parallelization**: Independent subsystem updates can run concurrently
- **Better Hardware Utilization**: Multi-core processors fully utilized
- **Improved Performance**: Potential for near-linear speedup with number of cores for parallel workloads
- **Future-Proofing**: Aligns with Python's evolution and long-term direction

### Compatibility Considerations
- **Python 3.13 Requirement**: Free-threaded mode requires Python 3.13 or later (released October 2024)
- **Library Compatibility**: Most popular libraries are being updated for free-threaded compatibility
- **Performance Characteristics**: Free-threaded mode has small overhead for single-threaded code (~5-10%)
- **Testing Requirements**: Requires additional testing for thread safety and race conditions

## Decision

We will adopt Python 3.13+ with free-threaded mode as the target runtime environment for City-Sim.

### Implementation Approach

1. **Minimum Python Version**: Set Python 3.13 as the minimum required version
2. **Free-Threaded Build**: Documentation and deployment will target free-threaded Python builds
3. **Thread-Safe Design**: All subsystems will be designed with thread safety in mind
4. **Parallel Tick Execution**: Implement parallel subsystem updates where dependencies allow
5. **Determinism Preservation**: Maintain deterministic behavior even with parallel execution
6. **Graceful Fallback**: Code will still function (albeit slower) in standard GIL-mode Python

### Parallelization Strategy

```python
# Example parallel tick execution structure
def execute_tick_parallel(city: City, context: TickContext) -> TickResult:
    """
    Execute tick with parallel subsystem updates.
    
    Execution graph:
    Phase 1 (Parallel): Environment, Population Growth
    Phase 2 (Parallel): Finance, Education, Healthcare (depend on Phase 1)
    Phase 3 (Sequential): Transportation (depends on all others)
    Phase 4 (Sequential): Aggregation and Logging
    """
    with ThreadPoolExecutor() as executor:
        # Phase 1: Independent subsystems
        environment_future = executor.submit(environment_subsystem.update, city, context)
        population_future = executor.submit(population_subsystem.update, city, context)
        
        environment_delta = environment_future.result()
        population_delta = population_future.result()
        
        # Phase 2: Subsystems depending on Phase 1
        finance_future = executor.submit(finance_subsystem.update, city, context)
        education_future = executor.submit(education_subsystem.update, city, context)
        healthcare_future = executor.submit(healthcare_subsystem.update, city, context)
        
        finance_delta = finance_future.result()
        education_delta = education_future.result()
        healthcare_delta = healthcare_future.result()
        
        # Phase 3: Transportation (depends on weather, population, employment)
        transport_delta = transport_subsystem.update(city, context)
        
        # Phase 4: Aggregation
        return aggregate_tick_results(environment_delta, population_delta, 
                                      finance_delta, education_delta,
                                      healthcare_delta, transport_delta)
```

### Thread Safety Requirements

1. **Immutable Data Structures**: Use immutable data structures where possible
2. **Copy-on-Write**: Subsystems receive copies of shared state
3. **Explicit Synchronization**: Use locks only when absolutely necessary
4. **Deterministic Ordering**: Ensure results are independent of thread scheduling
5. **No Shared Mutable State**: Subsystems do not modify shared state concurrently

### Determinism Preservation

Critical requirement: Parallel execution must produce identical results to sequential execution.

Strategies:
- **Seeded Random Number Generators**: Each subsystem gets its own seeded RNG from master seed
- **Ordered Aggregation**: Results aggregated in deterministic order regardless of completion order
- **No Race Conditions**: Careful design to eliminate data races
- **Testing**: Extensive testing comparing parallel and sequential execution results

## Consequences

### Positive Consequences

1. **Performance Improvement**: 2-4× speedup expected for tick execution on quad-core systems
2. **Scalability**: Simulation can scale to larger cities without proportional performance degradation
3. **Future-Ready**: Aligns with Python's long-term roadmap and community direction
4. **Developer Experience**: Pythonic threading is simpler than multiprocessing alternatives
5. **Real-Time Potential**: Fast enough execution for interactive gameplay with large cities

### Negative Consequences

1. **Version Requirement**: Python 3.13 requirement may limit adoption initially
2. **Complexity**: Thread safety adds complexity to implementation
3. **Testing Burden**: Requires more extensive testing for concurrency issues
4. **Library Compatibility**: Some third-party libraries may not be free-threaded compatible yet
5. **Small Single-Thread Overhead**: ~5-10% performance penalty for free-threaded mode in single-threaded code

### Migration Strategy

1. **Development Phase**: Develop on Python 3.13+ free-threaded builds
2. **Testing**: Comprehensive determinism tests comparing parallel and sequential results
3. **Documentation**: Update all documentation to reference Python 3.13+ requirement
4. **Dependencies**: Verify all dependencies are free-threaded compatible
5. **Fallback**: Maintain compatibility with standard Python 3.13 (with GIL) for users who need it

## Performance Targets

### Expected Improvements (4-core system)
- **Environment Subsystem**: 1.8-2.0× faster (highly parallelizable)
- **Population + Finance + Education + Healthcare**: 3.0-3.5× faster (independent updates)
- **Overall Tick**: 2.0-2.5× faster (limited by sequential dependencies)

### Scalability Targets
- **Small City (10k population)**: Single tick < 10ms
- **Medium City (100k population)**: Single tick < 50ms
- **Large City (1M population)**: Single tick < 200ms
- **Metropolis (10M population)**: Single tick < 1000ms

## Alternatives Considered

### Alternative 1: Multiprocessing
- **Pros**: Works with any Python version, true parallelism
- **Cons**: Higher overhead, more complex data sharing, harder to maintain determinism
- **Decision**: Rejected due to complexity and overhead

### Alternative 2: AsyncIO
- **Pros**: Works with current Python, good for I/O-bound tasks
- **Cons**: Cooperative multitasking, does not utilize multiple cores for CPU-bound work
- **Decision**: Rejected because our workload is CPU-bound, not I/O-bound

### Alternative 3: Cython or PyPy
- **Pros**: Significant performance improvements possible
- **Cons**: Additional compilation step, limited library compatibility, harder to maintain
- **Decision**: Rejected to maintain pure Python simplicity

### Alternative 4: Stay with Sequential Execution
- **Pros**: Simple, deterministic, no threading complexity
- **Cons**: Leaves significant performance on the table, does not scale
- **Decision**: Rejected because performance is important for large-scale simulations

## Implementation Timeline

### Phase 1: Foundation (Months 1-2)
- Update Python requirement to 3.13+
- Update all documentation
- Set up free-threaded development environment
- Create thread-safety guidelines

### Phase 2: Core Parallelization (Months 3-4)
- Implement parallel tick execution framework
- Parallelize Environment and Population subsystems
- Extensive determinism testing

### Phase 3: Extended Parallelization (Months 5-6)
- Parallelize Finance, Education, Healthcare subsystems
- Performance benchmarking
- Optimization of synchronization points

### Phase 4: Refinement (Months 7-8)
- Performance tuning
- Thread pool optimization
- Load balancing improvements
- Final testing and validation

## Monitoring and Validation

### Performance Monitoring
- Measure tick execution time before and after parallelization
- Track per-subsystem execution time
- Monitor thread utilization and load balance
- Identify remaining sequential bottlenecks

### Determinism Validation
- Automated tests comparing parallel and sequential execution
- Random seed variation testing
- Long-running simulation consistency checks
- Cross-platform validation (Linux, macOS, Windows)

## References

- **PEP 703**: Making the Global Interpreter Lock Optional in CPython
- **Python 3.13 Release Notes**: https://docs.python.org/3.13/whatsnew/3.13.html
- **Free-Threading Guide**: https://py-free-threading.github.io/
- **Performance Benchmarks**: Python 3.13 free-threading benchmarks
- **Related ADRs**: [ADR-001: Simulation Determinism](001-simulation-determinism.md)

## Decision Date
2026-02-17

## Decision Makers
- Project Lead: James Mortensen
- Technical Team
- AI Development Assistant

## Review Date
To be reviewed after Phase 2 implementation completion (estimated 4 months from decision date).
