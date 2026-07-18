# City Sim project context

## Repository orientation

- Primary entrypoint: `run.py`
- Source package: `src/`
- Tests: the repository's `test.sh` workflow and any test modules discovered under `tests/`
- Dependencies: `requirements.txt`
- Design and architecture references: `docs/`

## Standard commands

```bash
./init-venv.sh
source venv/bin/activate
python run.py
./test.sh
```

Use the repository's existing scripts and documentation as the source of truth
when they differ from this orientation note.

## Working conventions

- Preserve the existing Python package layout and README run path.
- Keep changes focused and avoid committing virtual environments, caches,
  generated logs, credentials, or bulky simulation output.
- For behavior changes, run the narrowest relevant test first, then `./test.sh`
  when practical.
- Leave a concise note in `.codex/handoffs/` when work is intentionally paused
  before completion.
