# Database/Save System

## Overview
This directory contains the database and save system for City-Sim. It manages game state persistence, allowing players to save their progress, load previous games, and maintain multiple save files.

## Purpose
- **Game Saves**: Store and load complete game states
- **Backups**: Automatic backup of save files
- **Version Migration**: Handle saves from different game versions
- **Data Persistence**: Reliable storage of city simulation data

## Directory Structure

```
db/
├── .github/              # Copilot instructions for this folder
├── _docs/                # Comprehensive documentation
│   ├── README.md         # Documentation index
│   └── local-usage-guide.md  # Usage guide
├── saves/                # Player save files (gitignored)
├── backups/              # Save file backups (gitignored)
├── schemas/              # JSON schemas for validation
├── migrations/           # Version migration scripts
└── templates/            # Save file templates
```

## Quick Start

### For Players
- **Save Game**: Press F5 or File → Save Game
- **Load Game**: Press F9 or File → Load Game
- **Save Location**: `db/saves/` directory
- **Backups**: Automatic backups in `db/backups/`

### For Developers
```python
from db.save_manager import SaveManager

# Save game
save_mgr = SaveManager()
save_mgr.save_game(city, save_slot='slot_1')

# Load game
city = save_mgr.load_game(save_slot='slot_1')
```

## Documentation
For detailed documentation, see:
- **Usage Guide**: [_docs/local-usage-guide.md](_docs/local-usage-guide.md)
- **Documentation Index**: [_docs/README.md](_docs/README.md)
- **Copilot Instructions**: [.github/copilot-instructions.md](.github/copilot-instructions.md)

## Features
- ✅ Multiple save slots (10 numbered + quicksave + autosave)
- ✅ Automatic backups before overwriting
- ✅ JSON-based save format (human-readable)
- ✅ Version migration support
- ✅ Save validation and corruption detection
- ✅ Metadata (city name, population, play time, screenshot)
- 🚧 Compression for large saves (planned)
- 🚧 SQLite format option (planned)
- 🚧 Cloud save sync (future)

## Python Version
- **Required**: Python 3.13 or later with free-threaded mode
  - See [ADR-002](../docs/adr/002-free-threaded-python.md) for detailed rationale
  - Installation guide: https://py-free-threading.github.io/installing_cpython/

## Status
- **Documentation**: ✅ Initial docs complete
- **Implementation**: 🚧 In progress
- **Testing**: 🚧 Planned

## Getting Help
1. Check [_docs/](_docs/) directory for guides
2. Review [.github/copilot-instructions.md](.github/copilot-instructions.md)
3. See main project documentation in [../docs/](../docs/)
4. Report issues on GitHub

---

**Note**: The `saves/` and `backups/` directories are gitignored to prevent committing player data. They will be created automatically when the game first runs.
