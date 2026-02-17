# GitHub Copilot Instructions for Database/Save System (db/)

## Overview

This directory contains the database and save system for the City-Sim project. The database layer manages game state persistence, allowing players to save their progress, load previous games, and maintain multiple save files. The system is designed for local, single-player saves with future extensibility for cloud saves or multiplayer scenarios.

## Core Principles

### Save System Philosophy
1. **Player Convenience**: Saving and loading should be fast and intuitive
2. **Data Integrity**: Never lose or corrupt player data
3. **Determinism Preservation**: Loaded games must restore exact game state
4. **Version Compatibility**: Handle save files from different game versions
5. **Performance**: Minimize save/load time impact on gameplay

### Design Goals
- **Local-First**: Primary support for local file-based saves
- **Format Flexibility**: Support multiple serialization formats (JSON, SQLite, binary)
- **Backward Compatibility**: Older saves should load in newer versions
- **Forward Migration**: Provide tools to migrate saves between versions
- **Disaster Recovery**: Enable backup and restore capabilities

## Directory Structure

```
db/
├── .github/                      # Copilot instructions (this file)
├── _docs/                        # Database documentation
│   ├── save-system-design.md    # Save system architecture and design
│   ├── data-schema.md           # Database schema and data model
│   ├── serialization-format.md  # Serialization format specifications
│   ├── migration-strategy.md    # Version migration approach
│   ├── backup-recovery.md       # Backup and recovery procedures
│   └── local-usage-guide.md     # How to use the db folder locally
├── saves/                        # Player save files (gitignored)
│   ├── slot_1/                  # Save slot 1
│   ├── slot_2/                  # Save slot 2
│   └── autosave/                # Autosave files
├── backups/                      # Save file backups (gitignored)
├── schemas/                      # JSON schemas for validation
│   ├── save_v1.schema.json     # Schema for version 1 saves
│   └── save_v2.schema.json     # Schema for version 2 saves
├── migrations/                   # Version migration scripts
│   ├── v1_to_v2.py             # Migrate v1 to v2
│   └── v2_to_v3.py             # Migrate v2 to v3
└── templates/                    # Save file templates
    ├── new_game.json            # Template for new game
    └── quickstart.json          # Template for quick start scenarios
```

## Python Version and Free-Threaded Support

### Current Environment
- **Python 3.12.3**: Current stable version in use
- **Target**: Python 3.13+ for free-threaded (no-GIL) support when stable

### Free-Threaded Considerations
- **Thread-Safe I/O**: Ensure file operations are thread-safe
- **Concurrent Saves**: Support saving while game continues running
- **Async Operations**: Consider async save/load for responsiveness
- **Lock-Free Reads**: Enable concurrent reads of save data without blocking

## Save System Architecture

### Core Components

#### 1. SaveManager
Central coordinator for save/load operations:

```python
class SaveManager:
    """Manages game save and load operations."""
    
    def save_game(self, city, save_slot='slot_1', metadata=None):
        """Save current game state to specified slot."""
        pass
    
    def load_game(self, save_slot='slot_1'):
        """Load game state from specified slot."""
        pass
    
    def list_saves(self):
        """List all available save files with metadata."""
        pass
    
    def delete_save(self, save_slot):
        """Delete a save file."""
        pass
    
    def export_save(self, save_slot, export_path):
        """Export save file for sharing or backup."""
        pass
```

#### 2. Serializer
Handles data serialization/deserialization:

```python
class Serializer:
    """Serializes and deserializes game state."""
    
    def serialize(self, city, format='json'):
        """Serialize city state to specified format."""
        pass
    
    def deserialize(self, data, format='json'):
        """Deserialize data to city state."""
        pass
```

#### 3. VersionManager
Manages save file versions and migrations:

```python
class VersionManager:
    """Manages save file version compatibility."""
    
    def get_save_version(self, save_file):
        """Determine version of save file."""
        pass
    
    def migrate_save(self, save_file, target_version):
        """Migrate save file to target version."""
        pass
    
    def is_compatible(self, save_version, game_version):
        """Check if save version is compatible with game version."""
        pass
```

#### 4. BackupManager
Handles backup and recovery:

```python
class BackupManager:
    """Manages save file backups."""
    
    def create_backup(self, save_slot):
        """Create backup of save file."""
        pass
    
    def restore_backup(self, backup_id, save_slot):
        """Restore save file from backup."""
        pass
    
    def list_backups(self, save_slot):
        """List available backups for a save slot."""
        pass
```

## Save File Format

### JSON Format (Default)
Human-readable, debuggable format:

```json
{
  "_metadata": {
    "version": "1.0",
    "game_version": "0.5.0",
    "save_time": "2024-02-17T01:00:00Z",
    "play_time_seconds": 3600,
    "save_name": "My City",
    "city_name": "Springfield"
  },
  "simulation": {
    "current_tick": 365,
    "seed": 42,
    "elapsed_time": 365
  },
  "city": {
    "name": "Springfield",
    "population": 1500,
    "budget": 75000.50,
    "infrastructure": {
      "water_facilities": 8,
      "electricity_units": 6,
      "roads": 25
    },
    "population_data": {
      "citizens": []  // Detailed citizen data if needed
    }
  },
  "policies": {
    "tax_rate": 0.15,
    "infrastructure_spending_ratio": 0.25
  },
  "events": [
    {
      "tick": 100,
      "type": "infrastructure_built",
      "details": {"facility": "water", "count": 1}
    }
  ]
}
```

### SQLite Format (Alternative)
Structured database for complex queries:

```sql
-- Schema for SQLite saves
CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE city_state (
    tick INTEGER PRIMARY KEY,
    population INTEGER,
    budget REAL,
    happiness REAL,
    -- other state fields
);

CREATE TABLE infrastructure (
    id INTEGER PRIMARY KEY,
    type TEXT,
    count INTEGER,
    condition REAL
);

CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tick INTEGER,
    type TEXT,
    data TEXT  -- JSON data
);
```

### Binary Format (Future)
Compact, fast format for large saves:

```python
# Binary format specification
# Header: 16 bytes
#   Magic number: 4 bytes (0x43495459 = "CITY")
#   Version: 2 bytes
#   Compression: 1 byte (0=none, 1=zlib, 2=lz4)
#   Reserved: 9 bytes
# Data: Variable length compressed data
```

## Serialization Strategies

### Full State Serialization
Save complete game state:

**Pros**:
- Complete restoration of exact state
- Simple implementation
- Easy debugging

**Cons**:
- Large file sizes
- Slower save/load times
- Contains redundant data

### Delta Serialization
Save only changes from baseline:

**Pros**:
- Smaller file sizes
- Faster saves
- Efficient for frequent autosaves

**Cons**:
- Complex implementation
- Requires baseline reference
- Harder to debug

### Hybrid Approach (Recommended)
Periodic full saves with delta autosaves:

```python
def save_strategy(tick, last_full_save_tick):
    """Determine save strategy based on timing."""
    if tick % 100 == 0:  # Every 100 ticks
        return 'full'
    else:
        return 'delta'
```

## Data Integrity

### Checksums
Validate save file integrity:

```python
import hashlib

def calculate_checksum(save_data):
    """Calculate SHA256 checksum of save data."""
    return hashlib.sha256(save_data.encode()).hexdigest()

def verify_checksum(save_data, expected_checksum):
    """Verify save data checksum."""
    return calculate_checksum(save_data) == expected_checksum
```

### Validation
Validate save data against schema:

```python
import jsonschema

def validate_save(save_data, schema_version='1.0'):
    """Validate save data against schema."""
    schema = load_schema(schema_version)
    try:
        jsonschema.validate(instance=save_data, schema=schema)
        return True
    except jsonschema.ValidationError as e:
        log_error(f"Save validation failed: {e.message}")
        return False
```

### Corruption Recovery
Handle corrupted saves:

```python
def load_with_recovery(save_slot):
    """Load save with automatic recovery attempts."""
    try:
        # Try primary save
        return load_save(save_slot)
    except CorruptionError:
        # Try backup
        return load_backup(save_slot, most_recent=True)
    except Exception as e:
        # Ultimate fallback
        log_error(f"Failed to load save: {e}")
        return None
```

## Performance Optimization

### Asynchronous Saves
Save without blocking gameplay:

```python
import asyncio

async def async_save_game(city, save_slot):
    """Save game asynchronously."""
    save_data = serialize_city(city)
    
    # Write to temp file
    temp_path = f"{save_slot}.tmp"
    await async_write_file(temp_path, save_data)
    
    # Atomic rename
    await async_rename(temp_path, save_slot)
```

### Incremental Saves
Update only changed data:

```python
def incremental_save(city, previous_state, save_slot):
    """Save only changes since previous state."""
    changes = calculate_diff(city, previous_state)
    
    if len(changes) < len(serialize_city(city)) * 0.3:
        # If changes < 30% of full state, save incrementally
        save_incremental(changes, save_slot)
    else:
        # Otherwise, do full save
        save_full(city, save_slot)
```

### Compression
Compress save files:

```python
import gzip
import json

def save_compressed(city, save_slot):
    """Save with compression."""
    save_data = json.dumps(serialize_city(city))
    
    with gzip.open(f"{save_slot}.gz", 'wt') as f:
        f.write(save_data)
```

## Version Migration

### Migration Process
1. Detect save version
2. Load with version-specific loader
3. Apply migrations sequentially
4. Validate migrated data
5. Save in current version

### Migration Example
```python
def migrate_v1_to_v2(v1_data):
    """Migrate save from v1 to v2 format."""
    v2_data = v1_data.copy()
    
    # Add new fields
    v2_data['_metadata']['version'] = '2.0'
    v2_data['traffic'] = {
        'roads': 0,
        'congestion': 0.0
    }
    
    # Rename fields
    v2_data['city']['electricity_infrastructure'] = (
        v2_data['city'].pop('electricity_units')
    )
    
    return v2_data
```

## Backup and Recovery

### Automatic Backups
Create backups automatically:

```python
def save_with_backup(city, save_slot, keep_backups=5):
    """Save game with automatic backup."""
    # Create backup of existing save
    if save_exists(save_slot):
        backup_id = create_backup(save_slot)
    
    # Save new data
    save_game(city, save_slot)
    
    # Cleanup old backups
    cleanup_old_backups(save_slot, keep=keep_backups)
```

### Manual Backups
Allow player-initiated backups:

```python
def create_manual_backup(save_slot, backup_name):
    """Create named backup of save file."""
    backup_path = f"db/backups/{save_slot}/{backup_name}"
    copy_save(save_slot, backup_path)
    
    return backup_path
```

## Best Practices

### DO
✅ Always validate save data before writing
✅ Use atomic file operations (write to temp, then rename)
✅ Create backups before overwriting saves
✅ Version all save formats
✅ Compress large save files
✅ Handle corruption gracefully
✅ Log save/load operations
✅ Test migration paths thoroughly

### DO NOT
❌ Overwrite saves without backup
❌ Store sensitive data in plain text
❌ Ignore version compatibility
❌ Block gameplay during saves
❌ Leave partial/corrupt saves
❌ Hardcode file paths
❌ Skip data validation
❌ Forget to handle edge cases

## Error Handling

### Common Errors
```python
class SaveSystemError(Exception):
    """Base exception for save system errors."""
    pass

class SaveCorruptedError(SaveSystemError):
    """Save file is corrupted."""
    pass

class SaveVersionError(SaveSystemError):
    """Save version incompatible."""
    pass

class InsufficientSpaceError(SaveSystemError):
    """Not enough disk space."""
    pass
```

### Error Recovery
```python
def robust_save(city, save_slot):
    """Save with comprehensive error handling."""
    try:
        # Pre-flight checks
        check_disk_space()
        validate_city_state(city)
        
        # Create backup
        if save_exists(save_slot):
            backup_id = create_backup(save_slot)
        
        # Perform save
        save_game(city, save_slot)
        
        # Verify save
        verify_save(save_slot)
        
    except InsufficientSpaceError:
        notify_user("Not enough disk space")
        cleanup_old_backups()
        retry_save()
        
    except Exception as e:
        log_error(f"Save failed: {e}")
        restore_backup(backup_id, save_slot)
        raise
```

## Testing Guidelines

### Save System Tests
```python
class TestSaveSystem(unittest.TestCase):
    """Tests for save system."""
    
    def test_save_load_roundtrip(self):
        """Saved game should load identically."""
        city = create_test_city()
        
        save_game(city, 'test_slot')
        loaded_city = load_game('test_slot')
        
        self.assertEqual(city.to_dict(), loaded_city.to_dict())
    
    def test_save_corruption_recovery(self):
        """System should recover from corrupted saves."""
        city = create_test_city()
        save_game(city, 'test_slot')
        
        # Corrupt the save
        corrupt_save('test_slot')
        
        # Should load from backup
        loaded_city = load_game('test_slot')
        self.assertIsNotNone(loaded_city)
    
    def test_version_migration(self):
        """Old saves should migrate to new version."""
        v1_save = create_v1_save()
        
        migrated = migrate_save(v1_save, target_version='2.0')
        
        self.assertEqual(migrated['_metadata']['version'], '2.0')
        validate_save(migrated, schema_version='2.0')
```

## Integration Points

### With Simulation Core
```python
# src/simulation/sim.py
class Simulation:
    def save(self, save_slot='slot_1'):
        """Save current simulation state."""
        save_manager = SaveManager()
        save_manager.save_game(
            city=self.city,
            save_slot=save_slot,
            metadata={
                'current_tick': self.current_tick,
                'seed': self.seed
            }
        )
    
    @classmethod
    def load(cls, save_slot='slot_1'):
        """Load simulation from save."""
        save_manager = SaveManager()
        save_data = save_manager.load_game(save_slot)
        
        return cls.from_save_data(save_data)
```

### With UI/CLI
```python
# UI Save/Load Interface
def show_save_dialog():
    """Display save game dialog."""
    saves = list_saves()
    selected = user_select_save_slot(saves)
    
    if confirm_overwrite(selected):
        save_game(current_city, selected)
        show_notification("Game Saved")
```

## Breadcrumbs for Top-Level Documentation

**ATTENTION - Docs Reconciliation Agent**:
This database/save system documentation should be integrated with:
1. Main architecture documentation
2. Game design documentation
3. File structure guidelines
4. Data management policies

**Key Integration Points**:
- Save system architecture in `docs/architecture/`
- Save file format in data specifications
- Player documentation for save management
- Developer guide for extending save system

**Open Items (OIs)**:
1. Cloud save integration design
2. Multiplayer/shared saves architecture
3. Save file encryption for security
4. Cross-platform save compatibility testing
5. Save file size optimization strategies
6. Automated save corruption detection
7. Player-facing save management UI
8. Developer tools for save inspection/editing
9. Save file analytics and telemetry
10. Integration with free-threaded Python (3.13+)

## Security Considerations

### Data Protection
- Validate all loaded data
- Sanitize file paths
- Prevent directory traversal
- Limit file sizes
- Rate-limit save operations

### Future: Encryption
```python
# For sensitive data in future versions
from cryptography.fernet import Fernet

def encrypt_save(save_data, key):
    """Encrypt save data."""
    f = Fernet(key)
    return f.encrypt(save_data.encode())

def decrypt_save(encrypted_data, key):
    """Decrypt save data."""
    f = Fernet(key)
    return f.decrypt(encrypted_data).decode()
```

## References and Resources

### Internal Documentation
- Save System Design: `_docs/save-system-design.md`
- Data Schema: `_docs/data-schema.md`
- Local Usage Guide: `_docs/local-usage-guide.md`
- Migration Strategy: `_docs/migration-strategy.md`

### External Resources
- Python JSON documentation
- SQLite documentation
- Python pickle security considerations
- File I/O best practices

### Tools
- `json`: JSON serialization
- `sqlite3`: SQLite database
- `jsonschema`: Schema validation
- `gzip`: Compression

---

**Document Version**: 1.0
**Last Updated**: 2024-02-17
**Maintainer**: Database/Save System Team
**Review Cycle**: Quarterly
