# Database Documentation Index

## Overview
This directory contains comprehensive documentation for the City-Sim database and save system.

## Documentation Files

### 1. [Local Usage Guide](local-usage-guide.md) ✅
**Purpose**: Practical guide for using the db/ folder locally

**Contents**:
- Quick start for players and developers
- Directory structure explanation
- Save file formats
- Common operations (save, load, backup, restore)
- Configuration options
- Troubleshooting guide
- Developer tools
- Best practices and FAQ

### 2. Save System Design (TODO)
**Purpose**: Architectural design of the save system

**Planned Contents**:
- System architecture and components
- SaveManager, Serializer, VersionManager, BackupManager designs
- Data flow diagrams
- Component interactions
- Design decisions and rationale
- Performance considerations
- Extensibility points

### 3. Data Schema (TODO)
**Purpose**: Complete database schema specification

**Planned Contents**:
- JSON schema definitions for all save file versions
- SQLite schema for database-backed saves
- Field descriptions and data types
- Relationships between entities
- Validation rules
- Schema versioning strategy
- Migration path documentation

### 4. Serialization Format (TODO)
**Purpose**: Detailed serialization format specifications

**Planned Contents**:
- JSON format specification
- SQLite format specification
- Binary format specification (future)
- Delta/incremental format (future)
- Compression strategies
- Format selection criteria
- Performance characteristics
- Trade-offs and recommendations

### 5. Migration Strategy (TODO)
**Purpose**: Version migration approach and procedures

**Planned Contents**:
- Migration philosophy and principles
- Version compatibility matrix
- Migration script architecture
- Step-by-step migration process
- Testing migration scripts
- Rollback procedures
- Edge case handling
- Migration validation

### 6. Backup and Recovery (TODO)
**Purpose**: Backup and disaster recovery procedures

**Planned Contents**:
- Backup strategies (automatic vs manual)
- Backup retention policies
- Recovery procedures
- Corruption detection and repair
- Data validation after recovery
- Disaster scenarios and responses
- Testing backup/recovery processes
- Player-facing backup features

## Quick Reference

### For Players
- **Saving a game**: See [Local Usage Guide § Saving a Game](local-usage-guide.md#saving-a-game)
- **Loading a game**: See [Local Usage Guide § Loading a Game](local-usage-guide.md#loading-a-game)
- **Managing saves**: See [Local Usage Guide § Managing Saves](local-usage-guide.md#managing-saves)
- **Troubleshooting**: See [Local Usage Guide § Troubleshooting](local-usage-guide.md#troubleshooting)

### For Developers
- **Architecture**: See Copilot Instructions (.github/copilot-instructions.md)
- **Integration**: See [Local Usage Guide § For Developers](local-usage-guide.md#for-developers)
- **Save format**: See [Local Usage Guide § Save File Format](local-usage-guide.md#save-file-format)
- **Developer tools**: See [Local Usage Guide § Developer Tools](local-usage-guide.md#developer-tools)

## Implementation Status

### Completed
- [x] Database folder structure created
- [x] Copilot instructions for db/ folder
- [x] Local usage guide documentation
- [x] Directory structure established

### In Progress
- [ ] Save system implementation
- [ ] Serialization modules
- [ ] Version management system
- [ ] Backup/restore functionality

### Planned
- [ ] Complete data schema documentation
- [ ] Save system design documentation
- [ ] Serialization format specifications
- [ ] Migration strategy documentation
- [ ] Backup/recovery documentation
- [ ] Schema validation implementation
- [ ] Migration scripts
- [ ] Developer tools (validator, inspector, etc.)
- [ ] Player-facing save management UI
- [ ] Unit and integration tests

## Design Principles (Summary)

### Player-First Design
1. **Convenience**: Fast, intuitive save/load
2. **Safety**: Never lose player progress
3. **Flexibility**: Multiple save slots, backups
4. **Transparency**: Clear save status and information

### Technical Excellence
1. **Determinism**: Saves restore exact game state
2. **Integrity**: Validation and corruption detection
3. **Performance**: Fast save/load operations
4. **Compatibility**: Version migration support
5. **Extensibility**: Easy to add new features

## Key Features

### Current Design
- **Multiple Save Slots**: 10 numbered slots + quicksave + autosave
- **Automatic Backups**: Backups created before overwriting
- **Version Migration**: Automatic migration of old saves
- **Format Flexibility**: JSON (default), SQLite, or binary
- **Compression**: Optional compression for large saves
- **Validation**: Schema-based validation on load/save
- **Metadata**: Rich save information (city name, population, play time, screenshot)

### Future Features
- **Cloud Saves**: Sync saves across devices
- **Multiplayer Saves**: Shared city saves
- **Incremental Saves**: Delta-based saves for efficiency
- **Encryption**: Encrypted save files for security
- **Export/Import**: Share saves with other players
- **Save Analytics**: Statistics and visualizations
- **Mod Support**: Save support for modded games

## Integration Points

### With Core Simulation
- Simulation class has save() and load() methods
- SaveManager interfaces with City and CityManager
- Deterministic state capture and restoration

### With UI/GUI
- File menu: Save Game, Load Game, Manage Saves
- Quick save/load keyboard shortcuts (F5/F9)
- Save slot selection dialog
- Save information display (metadata, screenshot)

### With Testing
- SaveSystemTests for save/load roundtrip
- Version migration tests
- Corruption recovery tests
- Performance tests for save/load operations

## Breadcrumbs for Documentation Reconciliation

**ATTENTION - Top-Level Docs Reconciliation Agent**:

This database/save system documentation needs to be integrated with:

### 1. Main Architecture Documentation
- Add save system to architecture overview
- Document save system component diagram
- Add to class hierarchy documentation
- Reference in data flow diagrams

### 2. Specifications
- Create save system specification in docs/specs/
- Add to module specifications index
- Document save system contracts and interfaces
- Specify error handling and edge cases

### 3. Design Workstreams
- Save system may span multiple workstreams:
  - Data & Logging (WS-06): Save file format, structured data
  - UI (WS-05): Save/load UI, save management interface
  - Core Simulation (WS-01): Integration with simulation loop
  - Testing (WS-07): Save system test strategy

### 4. ADRs (Architecture Decision Records)
Consider creating ADRs for:
- Choice of JSON as default format
- Version migration strategy
- Backup retention policy
- Autosave frequency and strategy

### 5. Contributing Guide
- Add save system development guidelines
- Document how to add new save file fields
- Explain version migration process
- Testing requirements for save system changes

### 6. README Updates
- Add save system to project overview
- Document where saves are stored
- Add quick start for players
- Link to detailed documentation

## Open Items (OIs)

### High Priority
1. **Implementation**: Complete save system implementation
2. **Testing**: Comprehensive test suite for save system
3. **Documentation**: Complete remaining documentation files
4. **Validation**: JSON schema definitions for all versions
5. **Migration**: Initial migration scripts

### Medium Priority
6. **Tools**: Developer tools (validator, inspector, differ)
7. **UI**: Player-facing save management interface
8. **Performance**: Optimization for large save files
9. **Compression**: Implement and test compression
10. **Backups**: Automatic backup cleanup policy

### Low Priority
11. **Cloud Saves**: Cloud save integration design
12. **Multiplayer**: Multiplayer save architecture
13. **Encryption**: Save file encryption for security
14. **Analytics**: Save file analytics and telemetry
15. **Mods**: Mod support in save system

### Future Enhancements
16. **Free-Threaded**: Async save/load with Python 3.13+
17. **Binary Format**: Compact binary save format
18. **Delta Saves**: Incremental delta-based saves
19. **Export/Import**: Cross-platform save sharing
20. **Save Editor**: Visual save file editor tool

## Cross-References

### Internal Documentation
- Main Copilot Instructions: `../../.github/copilot-instructions.md`
- Architecture Overview: `../../docs/architecture/overview.md`
- Simulation Spec: `../../docs/specs/simulation.md`
- City Spec: `../../docs/specs/city.md`
- Testing Copilot: `../../tests/.github/copilot-instructions.md`

### Database Documentation
- Copilot Instructions: `../.github/copilot-instructions.md`
- Local Usage Guide: `local-usage-guide.md`
- Save System Design: `save-system-design.md` (TODO)
- Data Schema: `data-schema.md` (TODO)
- Serialization Format: `serialization-format.md` (TODO)
- Migration Strategy: `migration-strategy.md` (TODO)
- Backup Recovery: `backup-recovery.md` (TODO)

## Contributing

When contributing to the save system:

1. **Read Documentation**: Start with Local Usage Guide and Copilot Instructions
2. **Follow Patterns**: Use existing patterns and conventions
3. **Test Thoroughly**: Add tests for all save system changes
4. **Document Changes**: Update relevant documentation
5. **Version Carefully**: Consider backward compatibility
6. **Validate Data**: Always validate saved data
7. **Handle Errors**: Graceful error handling and recovery

## Support and Questions

For questions about the database/save system:
1. Check this index and linked documentation
2. Review copilot instructions
3. Examine existing code in db/ directory
4. Check tests for examples
5. Consult architecture documentation
6. Ask on project discussion forums

---

**Document Version**: 1.0
**Last Updated**: 2024-02-17
**Maintainer**: Database/Save System Team
**Review Cycle**: After major save system changes
**Status**: Initial documentation complete, implementation in progress
