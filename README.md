

## Summary:
This project was developed on Apple Silicon (Arm64 based) Macintosh, using Microsoft Visual Studio Code Version: 1.72.0. The intention is to be compatible with any system through Python's multiplatform nature. However, this project will only be tested on Windows 10 amd64 machine and the latest MacOS version on an Arm64 machine.

**Important**: This project requires Python 3.13 or later with free-threaded mode (no Global Interpreter Lock) for optimal performance. Free-threaded Python enables true parallel execution across multiple CPU cores, providing significant performance improvements for large-scale city simulations. See [ADR-002: Free-Threaded Python](docs/adr/002-free-threaded-python.md) for detailed rationale. 

This program contains the following directories of interest under src:
- `./src/` - contains the source code for the program




## Scope:
    1. Definitions
    2. Prerequisites
    3. Initializing the Virtual Environment
    4. Running The Program From a Shell
    5. Running The Program
    6. Testing The Code base
    7. UML
## **1. Definitions:**
1) `"./" or "this directory"` - meaning the top level directory of this project, which happens to be the directory that this README.md file has been saved. The README.md is at the top level of this Python project.
2) `"Visual Studio Code"` - Microsoft Visual Studio Code integrated development environment

## **2. Prerequisites**
The *.sh scripts in this repository should be runnable on MacOS and Windows, as tested via the following shell programs.

### Shell Programs:
These shell programs have been integrated with Visual Studio Code using its Integrated Terminal features:
- Windows: MinGW (Minimalist GNU for Windows)
- MacOS: Zsh (Z shell)

Set one of these programs as the integrated terminal in Visual Studio Code.

**NOTE:** It is not in the scope of this document to show how to connect these terminals with Visual Studio Code, since this is straightforward and documented online with plenty of support.



### Development Environment and Interpreter:
- Visual Studio Code + Extensions: "Pylance v2022.10.30" and "Python v2022.16.1"
- **Python 3.13 or later (Free-Threaded Build)**: https://www.python.org/downloads/
  - Free-threaded Python (no Global Interpreter Lock) is required for optimal performance
  - See [Python 3.13 Release Notes](https://docs.python.org/3.13/whatsnew/3.13.html) for free-threading documentation
  - Installation Guide: https://py-free-threading.github.io/installing_cpython/


## **4. Initializing The Virtual Environment**

### Procedure:
In Visual Studio Code, using a system level install of Python 3.13 or later with free-threaded mode enabled.

1) Give executable rights to the script "./init-venv.sh".
2) In MinGW or Zsh run:
    ```
    ./init-venv.sh
    ```
3) A directory titled "./venv" should now be created.
4) At this time the python extension in Visual Studio Code should show an available interpreter called "venv" located at ./venv.

5) "./.vscode/settings.json" includes a setting that should automatically activate the selected virtual environment when a new integrated terminal is created (use Ctrl + ` to invoke a new terminal). 

    a) If Visual Studio Code does not automatically activate the virtual environment, then it may be necessary to run the following command manually:
    ```
    source ./venv/bin/activate
    ```

"(venv)" should now show at the beginning of each terminal line.

##  **5. Running The Program**

Bundled with the source code, as stated before, is the ./.vscode folder. This folder contains a "launch.json" file. This file is used to configure the Python extension to debug the program from the program entry point ./run.py.

./run.py is used to tell the interpreter that the top level of the project is the folder ".".

run.py can be invoked one of two ways, either through Visual Studio Code's integrated debug features, or via the virtual environment's interpreter via the shell.

### Shell and Python Interpreter Run Procedure:
1) Follow the procedure to initialize and activate the virtual environment.
2) Run the following command:
    ```
    python run.py
    ```

### Visual Studio Code Debugging
1) Change to the debugging sidebar view.
2) Next to the green arrow at the top of the sidebar, ensure "run.py" is selected as the current configuration.
3) Place a breakpoint in the program.
4) Click the green arrow.
5) Program should be running in debug mode at this time.


### Running the Executables

Future projects may provide a "frozen" version of the program, providing an executable package to the end user, which will bundle the interpreter with the executable as one set.

This is a placeholder for the procedure.



## **6. Testing Code Base**

Follow the above procedures for initializing the virtual environment, then run:

    ./test.sh

## **7. Unified Modeling Language (UML) Diagrams**
The Unified Modeling Language diagrams for this program have been provided in the folder `./docs/models`.

The model was developed using StarUML Educational License. Two output images were produced in portable network graphics and joint photographic experts group formats.

Models.mdj is the raw file that can be edited using StarUML.

## AI Development Documentation
Design docs and workstreams for future implementation are available:

- Design Overview: [docs/design/readme.md](docs/design/readme.md)
- Workstreams Index: [docs/design/workstreams/00-index.md](docs/design/workstreams/00-index.md)
- System Architecture: [docs/architecture/overview.md](docs/architecture/overview.md)
- Module Specs: [docs/specs/](docs/specs)
- ADRs: [docs/adr/](docs/adr)
- Guides: [docs/guides/](docs/guides)
