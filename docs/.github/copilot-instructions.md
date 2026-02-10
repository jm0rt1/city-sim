# Documentation Guidelines (docs/)

## Overview
This directory contains all project documentation including architecture, specifications, design workstreams, and guides. Documentation is a critical part of the project and must be kept in sync with code changes.

## Important: Read-Only vs. Update Required

### When Documentation Should Be Updated
- **Specs (docs/specs/)**: MUST be updated when changing module contracts or public APIs
- **Architecture (docs/architecture/)**: Update when adding/removing major components or changing subsystem boundaries
- **ADRs (docs/adr/)**: Add new ADRs for significant architectural decisions
- **Workstreams (docs/design/workstreams/)**: Update task backlogs and acceptance criteria as work progresses

### When Documentation Should NOT Be Modified
- Do not modify docs for minor implementation details
- Do not change historical ADRs (add new ones instead)
- Do not alter templates unless improving the template system itself
- Respect the specific instruction "do not modify docs" when given in a task

## Directory Structure

### Architecture Documentation (docs/architecture/)
- **overview.md**: High-level system architecture and design principles
- **class-hierarchy.md**: Detailed component relationships and responsibilities
- **Purpose**: Guide implementation and maintain architectural consistency
- **Update**: When adding major components or changing subsystem boundaries

### Specifications (docs/specs/)
Contains detailed module specifications:
- **simulation.md**: Simulation core tick loop contract
- **city.md**: City model data structures and invariants
- **finance.md**: Budget, revenue, expense calculations
- **population.md**: Population dynamics and happiness
- **traffic.md**: Transport network and traffic simulation
- **logging.md**: Structured logging schema
- **scenarios.md**: Baseline scenario definitions

**Critical**: Update specs when changing module interfaces or contracts

### Design & Workstreams (docs/design/)
- **readme.md**: Guide to AI-followable documentation
- **workstreams/**: 10 parallel development workstreams (01-10)
- **templates/**: Templates for tasks, specs, experiments
- **prompts.md**: Consolidated prompts for workstreams

**Purpose**: Coordinate parallel development work
**Update**: Task backlogs, checkpoints, and completion status

### Architecture Decision Records (docs/adr/)
- **000-template.md**: ADR template
- **001-simulation-determinism.md**: Determinism decision and rationale

**Critical**: Never modify existing ADRs; add new ones for new decisions
**Format**: Use template, include status, context, decision, consequences

### Guides (docs/guides/)
- **contributing.md**: Contribution workflow and standards
- **glossary.md**: Key terminology definitions

**Purpose**: Onboarding and reference
**Update**: When adding new patterns or terminology

### Models (docs/models/)
- **model.mdj**: StarUML model file
- **Purpose**: Visual architecture diagrams
- **Update**: Rarely; when major structural changes occur

## Documentation Standards

### Writing Style
- Clear and concise
- Use present tense
- Active voice preferred
- Avoid jargon without definition
- Include examples where helpful

### Markdown Conventions
- Use ATX-style headers (`#`, `##`, `###`)
- Code blocks with language specifiers: ```python
- Relative links to other docs: `[text](../path/file.md)`
- Lists with consistent formatting (either `*` or `-`)

### Code Examples
- Keep examples minimal and focused
- Use realistic variable names
- Include docstrings in function examples
- Show both correct and incorrect patterns when useful

## Updating Specifications

When changing a module's public API or contract:

1. **Read the current spec** (docs/specs/)
2. **Understand the contract** and invariants
3. **Make your code changes**
4. **Update the spec** to reflect new behavior:
   - Interfaces section for API changes
   - Inputs/Outputs for parameter changes
   - Invariants for constraint changes
   - Acceptance Criteria for new requirements
5. **Review consistency** between code and spec

**Note**: When documenting changes for review, you may temporarily mark new additions with "NEW -" prefix to help reviewers identify changes. Remove these markers after the change is merged. This is optional and primarily useful for complex spec updates with many changes.

### Example: Updating finance.md
```markdown
## Interfaces
- `Finance.update(city, context)`: computes revenue and expenses per tick.
- `Finance.compute_taxes(city, tax_rate)`: NEW - calculates tax revenue

## Inputs
- City state and policy parameters.
- Tax rate (float, 0.0-1.0) - NEW

## Acceptance Criteria
- Budget equation holds within floating‑point tolerance.
- Policies affect revenue/expenses predictably.
- Tax calculations are deterministic - NEW
```

## Creating ADRs

When making a significant architectural decision:

1. Copy `docs/adr/000-template.md`
2. Number sequentially (e.g., `002-decision-name.md`)
3. Fill in all sections:
   - **Status**: Proposed, Accepted, Deprecated, Superseded
   - **Context**: What is the situation and problem?
   - **Decision**: What decision did we make?
   - **Consequences**: What are the implications?
4. Link to relevant specs and workstreams

### Example ADR Topics
- Switching to a new logging format
- Adding a new subsystem
- Changing the determinism model
- Major performance optimizations
- Breaking API changes

## Workstream Documentation

Each workstream file contains:
- **Reading Checklist**: Prerequisites to understand
- **Objectives**: What the workstream aims to achieve
- **Scope**: Files and areas of focus
- **Inputs/Outputs**: What goes in and comes out
- **Run Steps**: Commands to execute
- **Task Backlog**: Specific tasks to complete
- **Acceptance Criteria**: Definition of done
- **Checkpoints**: Incremental milestones

### Updating Workstreams
- Mark completed tasks: `- [x] Task description`
- Add new tasks as discovered: `- [ ] New task`
- Update acceptance criteria when requirements change
- Keep run steps current with actual commands

## Cross-References

Documentation is interconnected. When updating one file, consider:
- Do other specs reference this module?
- Are there workstreams depending on this?
- Do ADRs need updating or new ones created?
- Should the architecture overview be updated?

### Common Cross-Reference Patterns
```markdown
# In spec files
See ADR: [001-simulation-determinism.md](../adr/001-simulation-determinism.md)
Workstream: [01-simulation-core.md](../design/workstreams/01-simulation-core.md)

# In workstream files
Spec: [simulation.md](../../specs/simulation.md)
Architecture: [overview.md](../../architecture/overview.md)

# In ADR files
Spec: [Simulation](../specs/simulation.md)
Workstream: [Simulation Core](../design/workstreams/01-simulation-core.md)
```

## Documentation Quality Checklist

Before considering documentation complete:
- [ ] All code changes reflected in relevant specs
- [ ] Links between docs are valid and up-to-date
- [ ] Examples compile and run (if code examples)
- [ ] Terminology consistent with glossary
- [ ] Cross-references accurate
- [ ] Spelling and grammar checked
- [ ] Markdown renders correctly

## Anti-Patterns to Avoid

❌ **Outdated specs after code changes**
- Always update specs when changing public APIs

❌ **Vague acceptance criteria**
- Be specific: "Population should increase" → "Population should grow by 5-10% per tick under baseline scenario"

❌ **Broken links**
- Verify all relative links work

❌ **Modifying historical ADRs**
- Add new ADRs instead; reference superseded ones

❌ **Duplicating information**
- Reference other docs instead of copying content

## Special Cases

### Generated Documentation
Currently no auto-generated docs. If added:
- Mark generated sections clearly
- Don't manually edit generated sections
- Update generation scripts instead

### External Documentation
- README.md is in root, not docs/
- Keep it in sync with docs/architecture/overview.md high-level points
- README focuses on getting started; docs/ has details

## References
- Main Instructions: ../.github/copilot-instructions.md
- Contributing Guide: docs/guides/contributing.md
- ADR Template: docs/adr/000-template.md
- Workstream Template: docs/design/templates/workstream_prompt.md
