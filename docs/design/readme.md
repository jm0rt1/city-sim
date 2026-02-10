# City‑Sim Design & Workstreams Guide

This guide provides an AI‑followable documentation tree to coordinate parallel workstreams for the city building simulation. It defines clear inputs, outputs, run steps, checkpoints, and acceptance criteria so human and AI collaborators can execute tasks safely and consistently.

## How To Use
- Start at the Workstreams Index: see [docs/design/workstreams/00-index.md](workstreams/00-index.md).
- Pick a workstream and open its file; each has Objectives, Task Backlog, Run Steps, and a tailored copy‑paste Prompt.
- Author new tasks using the template in [docs/design/templates/task_card.md](templates/task_card.md). Larger efforts should use [templates/design_spec.md](templates/design_spec.md) or [templates/experiment_plan.md](templates/experiment_plan.md).
- Keep changes minimal and consistent with the existing codebase style.

## Context
- Code entry points: [run.py](../../run.py), [src/main.py](../../src/main.py).
- Core modules: [src/simulation/sim.py](../../src/simulation/sim.py), [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py), [src/city/finance.py](../../src/city/finance.py), [src/city/population/population.py](../../src/city/population/population.py), [src/city/population/happiness_tracker.py](../../src/city/population/happiness_tracker.py), [src/shared/settings.py](../../src/shared/settings.py), [src/city/decisions.py](../../src/city/decisions.py).
- Logs: [output/logs/global/](../../output/logs/global/) for global runs; UI logs in [output/logs/ui/](../../output/logs/ui/).
- Tests: expand from [tests/core/test_dummy.py](../../tests/core/test_dummy.py) in the Testing workstream.

## Parallel Workstreams
Workstreams are designed to run independently where possible:
1. Simulation Core – algorithm correctness and tick loop performance.
2. City Modeling – data structures and state transitions.
3. Finance – budget, revenue/expenses, policy effects.
4. Population – growth, happiness, migration.
5. UI – CLI or future GUI generation and UX.
6. Data & Logging – metrics, structured logs, and reproducibility.
7. Testing & CI – unit/integration tests and static analysis.
8. Performance – profiling and optimization.
9. Roadmap – release planning and cross‑workstream dependencies.

See the index at [workstreams/00-index.md](workstreams/00-index.md) for details and links.

For quick copy‑paste, see consolidated prompts: [prompts.md](prompts.md)

## Quick Run
Use the following commands to run and test locally on macOS:

```bash
# Create and activate venv (if needed)
./init-venv.sh

# Install dependencies
pip install -r requirements.txt

# Run the simulation
python3 run.py

# Run tests
./test.sh
```

## Initial Documentation
For historical notes and original scoping, see [initial_documentation.md](initial_documentation.md).

## Future Improvements

This section tracks potential enhancements and areas for future development.

### Documentation Enhancements
- **Interactive Tutorials**: Create step-by-step tutorials for common development tasks
- **Video Walkthroughs**: Record video explanations of complex subsystems
- **API Reference Generator**: Automate API documentation from code docstrings
- **Diagram Automation**: Generate UML diagrams automatically from code
- **Decision Trees**: Add flowcharts for common decision-making processes

### Architecture & Design
- **Microservices Architecture**: Consider splitting into microservices for very large-scale simulations
- **Plugin System**: Formalize plugin architecture for third-party extensions
- **Event Sourcing**: Implement full event sourcing for complete state replay capability
- **CQRS Pattern**: Separate read and write models for better performance
- **Distributed Computing**: Support for running simulations across multiple machines

### Simulation Features
- **Weather System**: Add weather simulation affecting traffic, happiness, and infrastructure
- **Seasonal Effects**: Model seasonal variations in population, traffic, and economics
- **Crime Modeling**: Simulate crime rates and their impact on city dynamics
- **Environmental Factors**: Track pollution, green spaces, and environmental quality
- **Education System**: More detailed education pipeline from K-12 to higher education
- **Healthcare System**: Detailed healthcare capacity and disease modeling
- **Economic Sectors**: Model distinct economic sectors (tech, manufacturing, services)
- **Labor Market**: Simulate employment, unemployment, and job matching

### Transport & Traffic
- **Public Transit**: Add buses, trains, subways with scheduling and capacity
- **Pedestrian Simulation**: Model foot traffic and pedestrian infrastructure
- **Bicycle Networks**: Add cycling infrastructure and behavior
- **Multi-Modal Routing**: Support routes combining multiple transport modes
- **Real-Time Traffic Data**: Integration with real traffic data sources
- **Parking Simulation**: Model parking availability and behavior
- **Autonomous Vehicles**: Simulate mixed fleets with autonomous vehicles

### Performance & Scalability
- **GPU Acceleration**: Use GPU for large-scale traffic simulation
- **Parallel Subsystems**: Execute independent subsystems concurrently
- **Incremental Simulation**: Support partial updates for very large cities
- **Lazy Evaluation**: Compute metrics only when needed
- **Memory Optimization**: Reduce memory footprint for long-running simulations
- **Database Integration**: Store large city states in database for persistence

### User Interface
- **Web Dashboard**: Real-time web-based visualization dashboard
- **3D Visualization**: Interactive 3D city rendering
- **Mobile App**: Mobile interface for monitoring simulations
- **VR/AR Support**: Immersive visualization of city simulation
- **Collaborative Editing**: Multiple users editing scenarios simultaneously

### Testing & Quality
- **Mutation Testing**: Verify test suite quality through mutation testing
- **Performance Regression Tests**: Automated detection of performance degradation
- **Chaos Engineering**: Test resilience under failure conditions
- **Fuzz Testing**: Automated discovery of edge cases
- **Property-Based Testing**: Expand property-based test coverage

### Data & Analytics
- **Machine Learning Integration**: Use ML for predictive analytics and optimization
- **Anomaly Detection**: Automatic detection of unusual simulation behavior
- **Scenario Optimization**: AI-driven scenario parameter optimization
- **Visualization Library**: Rich charting and graphing capabilities
- **Data Export Formats**: Support additional export formats (Parquet, Arrow, HDF5)

### Development Experience
- **Live Reload**: Hot-reload for faster development iteration
- **Interactive REPL**: Python REPL with city simulation context loaded
- **Debugging Tools**: Enhanced debugging with state inspection and time travel
- **Code Generation**: Generate boilerplate code for new subsystems
- **Development Containers**: Standardized dev containers for consistent environments

### Integration & Deployment
- **Cloud Deployment**: Deploy simulations to cloud platforms (AWS, Azure, GCP)
- **Containerization**: Docker images for easy deployment
- **CI/CD Pipeline**: Comprehensive continuous integration and deployment
- **Monitoring & Alerting**: Production monitoring for long-running simulations
- **API Gateway**: RESTful API for external system integration

### Community & Collaboration
- **Plugin Marketplace**: Repository for community-contributed plugins
- **Scenario Sharing**: Platform for sharing and discovering scenarios
- **Best Practices Guide**: Comprehensive guide for common patterns
- **Case Studies**: Real-world applications and success stories
- **Community Forums**: Discussion forums for users and developers

### Research & Experimentation
- **A/B Testing Framework**: Built-in support for controlled experiments
- **Sensitivity Analysis Tools**: Analyze parameter sensitivity automatically
- **Comparative Studies**: Tools for comparing multiple scenarios
- **Research Export**: Export data in formats suitable for academic research
- **Reproducibility Pack**: Bundle code, data, and environment for full reproducibility
