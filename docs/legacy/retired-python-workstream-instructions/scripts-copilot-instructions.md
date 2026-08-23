# Scripts Documentation and Usage Guide

## Overview
This directory contains shell scripts that automate common development tasks for the City-Sim project. These scripts support environment setup, testing, dependency management, and UI generation.

## Available Scripts

### Core Development Scripts

#### 1. `../init-venv.sh` - Virtual Environment Initialization
**Purpose**: Set up Python virtual environment and install dependencies

**Usage**:
```bash
./init-venv.sh
```

**What it does**:
1. Creates Python virtual environment in `./venv`
2. Activates the virtual environment
3. Installs dependencies from `requirements.txt`
4. Installs development tools (autopep8)

#### 2. `../test.sh` - Run Test Suite
**Purpose**: Execute all unit and integration tests

**Usage**:
```bash
./test.sh
```

**What it does**:
1. Discovers and runs tests matching `*test*.py` pattern
2. Discovers and runs tests matching `*Test*.py` pattern
3. Reports test results

#### 3. `../freeze-venv.sh` - Freeze Dependencies
**Purpose**: Capture current environment dependencies

**Usage**:
```bash
./freeze-venv.sh
```

**What it does**:
1. Detects operating system (macOS or Windows)
2. Activates appropriate virtual environment
3. Runs `pip freeze` to capture dependencies
4. Writes dependencies to `requirements.txt`

#### 4. `../generate_ui.sh` - Generate UI Code
**Purpose**: Generate Python code from Qt UI files

**Usage**:
```bash
./generate_ui.sh
```

**What it does**:
1. Runs `pyside6-uic` to convert `.ui` files to Python
2. Generates `src/gui/views/generated/main_window.py`

## Script Enhancement Opportunities

### Planned Enhancements
- Add coverage reporting to test.sh
- Add linting and formatting scripts
- Create database maintenance scripts  
- Add pre-commit hook scripts
- Implement parallel test execution
- Create build and deployment scripts

For full documentation, see README in this directory (to be created).

---

**Document Version**: 1.0
**Last Updated**: 2024-02-17
