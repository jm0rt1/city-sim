# Local Usage Guide for Database/Save System

## Purpose
This guide explains how to use the `./db` folder locally for managing City-Sim game saves, backups, and data persistence. It provides practical instructions for developers and players.

## Quick Start

### For Players

#### Saving a Game
1. Press F5 (or use menu: File → Save Game)
2. Select a save slot (1-10) or create named save
3. Game state is saved to `db/saves/slot_X/`

#### Loading a Game
1. Press F9 (or use menu: File → Load Game)
2. Select save slot to load
3. Game restores to exact saved state

#### Managing Saves
- View all saves: `db/saves/` directory
- Each save slot contains:
  - `game_state.json`: Main save file
  - `metadata.json`: Save information (date, time, city name)
  - `thumbnail.png`: Screenshot of city (if enabled)

### For Developers

#### Directory Setup
```bash
cd /path/to/city-sim

# Database directories are auto-created on first run
# Or manually create:
mkdir -p db/{saves,backups,schemas,migrations,templates}
```

#### Basic Save Operations
```python
from db.save_manager import SaveManager

# Initialize save manager
save_mgr = SaveManager()

# Save game
save_mgr.save_game(city, save_slot='slot_1')

# Load game
city = save_mgr.load_game(save_slot='slot_1')

# List all saves
saves = save_mgr.list_saves()
for save in saves:
    print(f"{save['slot']}: {save['city_name']} - {save['save_time']}")
```

## Directory Structure

### `/db/saves/` - Player Save Files
Contains all player saves organized by slot:

```
db/saves/
├── slot_1/
│   ├── game_state.json          # Complete game state
│   ├── metadata.json            # Save information
│   └── thumbnail.png            # City screenshot
├── slot_2/
│   └── ...
├── autosave/
│   ├── autosave_0.json         # Rolling autosaves
│   ├── autosave_1.json
│   └── autosave_2.json
└── quicksave/
    └── quicksave.json           # Quick save (F6)
```

**Note**: This directory is gitignored to prevent committing player data.

### `/db/backups/` - Backup Files
Automatic backups of save files:

```
db/backups/
├── slot_1/
│   ├── backup_2024-02-17_01-00-00.json
│   ├── backup_2024-02-17_02-00-00.json
│   └── backup_2024-02-17_03-00-00.json
└── slot_2/
    └── ...
```

**Configuration**:
- Backups created before overwriting saves
- Keep last 5 backups per slot (configurable)
- Automatic cleanup of old backups

### `/db/schemas/` - JSON Schemas
Validation schemas for save files:

```
db/schemas/
├── save_v1.schema.json         # Schema for version 1.0 saves
├── save_v2.schema.json         # Schema for version 2.0 saves
└── metadata.schema.json        # Schema for metadata files
```

**Purpose**:
- Validate save file structure
- Ensure data integrity
- Document save format

### `/db/migrations/` - Version Migration Scripts
Scripts to migrate saves between versions:

```
db/migrations/
├── __init__.py
├── v1_to_v2.py                 # Migrate v1 → v2
├── v2_to_v3.py                 # Migrate v2 → v3
└── migration_utils.py          # Migration helpers
```

**Usage**:
```bash
# Migrate a save file
python -m db.migrations.migrate --input slot_1/game_state.json --target-version 2.0
```

### `/db/templates/` - Save Templates
Templates for new games and scenarios:

```
db/templates/
├── new_game.json               # Standard new game
├── tutorial.json               # Tutorial scenario
├── sandbox.json                # Sandbox mode
└── challenge_1.json            # Challenge scenario
```

## Save File Format

### Main Save File (`game_state.json`)
```json
{
  "_metadata": {
    "version": "1.0",
    "game_version": "0.5.0",
    "save_time": "2024-02-17T01:00:00Z",
    "play_time_seconds": 3600
  },
  "simulation": {
    "current_tick": 365,
    "seed": 42
  },
  "city": {
    "name": "Springfield",
    "population": 1500,
    "budget": 75000.50,
    "infrastructure": {
      "water_facilities": 8,
      "electricity_units": 6
    }
  }
}
```

### Metadata File (`metadata.json`)
```json
{
  "save_name": "My City - Day 365",
  "city_name": "Springfield",
  "population": 1500,
  "play_time_formatted": "1h 0m",
  "save_time": "2024-02-17T01:00:00Z",
  "game_version": "0.5.0",
  "has_thumbnail": true
}
```

## Common Operations

### Creating a Save
```python
from db.save_manager import SaveManager
from src.city.city import City

# Create save manager
save_mgr = SaveManager()

# Create or load city
city = City()
# ... play game ...

# Save to slot 1
save_mgr.save_game(
    city=city,
    save_slot='slot_1',
    metadata={
        'save_name': 'My Amazing City',
        'notes': 'Just built first water facility'
    }
)
```

### Loading a Save
```python
from db.save_manager import SaveManager

save_mgr = SaveManager()

# Load from slot 1
city = save_mgr.load_game(save_slot='slot_1')

# Or with validation
try:
    city = save_mgr.load_game(save_slot='slot_1', validate=True)
except SaveValidationError as e:
    print(f"Save validation failed: {e}")
```

### Listing Saves
```python
saves = save_mgr.list_saves()

for save in saves:
    print(f"Slot: {save['slot']}")
    print(f"City: {save['city_name']}")
    print(f"Population: {save['population']}")
    print(f"Saved: {save['save_time']}")
    print(f"Play Time: {save['play_time_formatted']}")
    print()
```

### Deleting a Save
```python
# Delete save (moves to backup first)
save_mgr.delete_save(save_slot='slot_1', backup=True)

# Or permanently delete
save_mgr.delete_save(save_slot='slot_1', backup=False, confirm=True)
```

### Creating Backups
```python
# Manual backup
backup_id = save_mgr.create_backup(save_slot='slot_1')
print(f"Backup created: {backup_id}")

# List backups for a slot
backups = save_mgr.list_backups(save_slot='slot_1')
for backup in backups:
    print(f"{backup['id']}: {backup['created_time']}")
```

### Restoring from Backup
```python
# Restore most recent backup
save_mgr.restore_backup(save_slot='slot_1', backup_id='most_recent')

# Or restore specific backup
save_mgr.restore_backup(save_slot='slot_1', backup_id='backup_2024-02-17_01-00-00')
```

## Configuration

### Save Settings
Configure save behavior in `src/shared/settings.py`:

```python
class SaveSettings:
    # Save directory
    SAVE_DIR = "db/saves"
    
    # Backup settings
    BACKUP_DIR = "db/backups"
    MAX_BACKUPS_PER_SLOT = 5
    AUTO_BACKUP_ON_SAVE = True
    
    # Autosave settings
    AUTOSAVE_ENABLED = True
    AUTOSAVE_INTERVAL_TICKS = 100  # Every 100 ticks
    MAX_AUTOSAVES = 3
    
    # File format
    DEFAULT_FORMAT = "json"  # or "sqlite" or "binary"
    COMPRESS_SAVES = False
    
    # Validation
    VALIDATE_ON_LOAD = True
    VALIDATE_ON_SAVE = True
```

### Customizing Save Location
```python
# Use custom save directory
save_mgr = SaveManager(save_dir="/custom/path/to/saves")

# Or set globally
import os
os.environ['CITY_SIM_SAVE_DIR'] = "/custom/path"
```

## Troubleshooting

### Save Won't Load
**Problem**: Error loading save file

**Solutions**:
1. Check save file exists: `ls db/saves/slot_1/`
2. Validate save file: `python -m db.tools.validate save_slot_1`
3. Try loading backup: `save_mgr.restore_backup('slot_1', 'most_recent')`
4. Check game version compatibility

### Corrupted Save
**Problem**: Save file corrupted or invalid

**Solutions**:
1. Restore from backup: `save_mgr.restore_backup('slot_1')`
2. Use save repair tool: `python -m db.tools.repair game_state.json`
3. Manual edit JSON file (advanced users)

### Insufficient Disk Space
**Problem**: Cannot save due to lack of space

**Solutions**:
1. Delete old saves: `save_mgr.delete_save('old_slot')`
2. Cleanup old backups: `save_mgr.cleanup_old_backups()`
3. Enable compression: `SaveSettings.COMPRESS_SAVES = True`
4. Move save directory to larger drive

### Version Incompatibility
**Problem**: Save from different game version

**Solutions**:
1. Check if migration available: `save_mgr.can_migrate('slot_1')`
2. Migrate save: `python -m db.migrations.migrate --slot slot_1`
3. Check migration logs for issues

## Advanced Usage

### Custom Serialization
```python
from db.serializers import JSONSerializer, SQLiteSerializer

# Use SQLite for large saves
serializer = SQLiteSerializer()
save_mgr = SaveManager(serializer=serializer)

# Save to SQLite database
save_mgr.save_game(city, 'slot_1')
# Creates: db/saves/slot_1/game_state.db
```

### Compression
```python
from db.save_manager import SaveManager

# Enable compression
save_mgr = SaveManager(compress=True)

# Saves as .json.gz
save_mgr.save_game(city, 'slot_1')
# Creates: db/saves/slot_1/game_state.json.gz

# Loading handles decompression automatically
city = save_mgr.load_game('slot_1')
```

### Async Save/Load
```python
import asyncio
from db.save_manager import AsyncSaveManager

async def save_async():
    save_mgr = AsyncSaveManager()
    
    # Non-blocking save
    await save_mgr.save_game_async(city, 'slot_1')
    
    # Game continues running during save
    print("Save in progress...")

asyncio.run(save_async())
```

### Exporting Saves
```python
# Export save for sharing
save_mgr.export_save(
    save_slot='slot_1',
    export_path='~/Desktop/my_city_save.csav'
)

# Import save
save_mgr.import_save(
    import_path='~/Downloads/friend_city.csav',
    save_slot='slot_5'
)
```

### Save Analytics
```python
from db.tools.analyzer import SaveAnalyzer

analyzer = SaveAnalyzer()

# Analyze save file
stats = analyzer.analyze_save('slot_1')
print(f"File size: {stats['file_size_mb']} MB")
print(f"Population: {stats['population']}")
print(f"Play time: {stats['play_time_hours']} hours")
print(f"Compression ratio: {stats['compression_ratio']}")
```

## Developer Tools

### Save Validator
```bash
# Validate all saves
python -m db.tools.validate --all

# Validate specific slot
python -m db.tools.validate --slot slot_1

# Validate with detailed output
python -m db.tools.validate --slot slot_1 --verbose
```

### Save Inspector
```bash
# Inspect save file
python -m db.tools.inspect db/saves/slot_1/game_state.json

# Output:
# Version: 1.0
# Game Version: 0.5.0
# City: Springfield
# Population: 1500
# Budget: $75,000.50
# Play Time: 1h 0m
```

### Save Differ
```bash
# Compare two saves
python -m db.tools.diff \
    db/saves/slot_1/game_state.json \
    db/saves/slot_2/game_state.json

# Output shows differences between saves
```

### Save Migrator
```bash
# Migrate save to current version
python -m db.migrations.migrate \
    --input db/saves/slot_1/game_state.json \
    --output db/saves/slot_1/game_state_migrated.json

# Or migrate in-place
python -m db.migrations.migrate \
    --slot slot_1 \
    --in-place
```

## Best Practices

### For Players
✅ Use multiple save slots for important games
✅ Create manual backups before major decisions
✅ Enable autosave for safety
✅ Regularly cleanup old saves
✅ Export saves before game updates

### For Developers
✅ Always validate saves on load
✅ Create backups before overwriting
✅ Use atomic file operations
✅ Handle missing/corrupted files gracefully
✅ Version save formats properly
✅ Test save/load frequently
✅ Document save format changes

## Security Notes

### Data Privacy
- Save files stored locally on player's machine
- No data sent to external servers (unless cloud saves enabled)
- Save files are plain text JSON (readable by player)

### File Safety
- Never store passwords or sensitive data in saves
- Validate all loaded data before use
- Limit file sizes to prevent abuse
- Sanitize file paths to prevent directory traversal

## FAQ

**Q: Where are my save files?**
A: In `db/saves/` directory relative to game installation.

**Q: Can I edit save files manually?**
A: Yes, they're JSON format, but validate after editing.

**Q: How do I backup my saves?**
A: Copy entire `db/saves/` directory or use export feature.

**Q: Can I share saves with friends?**
A: Yes, use File → Export Save, then share the .csav file.

**Q: What if my save is corrupted?**
A: Try loading from backup in `db/backups/` directory.

**Q: How much disk space do saves use?**
A: Typically 1-10 MB per save (depends on city size).

**Q: Can I save while game is paused?**
A: Yes, saving works at any time.

**Q: Are saves compatible between versions?**
A: Generally yes, with automatic migration when needed.

## Support

### Getting Help
1. Check this documentation first
2. Verify save file integrity with validator
3. Check game logs for error messages
4. Try restoring from backup
5. Report issues on GitHub with:
   - Game version
   - Save file (if shareable)
   - Error messages
   - Steps to reproduce

### Reporting Bugs
```bash
# Generate diagnostic report
python -m db.tools.diagnostics --slot slot_1 --output report.txt
```

Include report when filing bug reports.

---

**Last Updated**: 2024-02-17
**Version**: 1.0
**Maintainer**: Database/Save System Team
