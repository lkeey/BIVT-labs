# Python Labs Repository

This repository contains laboratory works for Python programming course.

## Laboratory Works

- [Laboratory Work 1](src/lab01/README.md) - Basic Python syntax and input/output operations
- [Laboratory Work 2](src/lab02/README.md) - Working with arrays, matrices, and tuples
- [Laboratory Work 3](src/lab03/README.md) - Text processing and frequency analysis
- [Laboratory Work 4](src/lab04/README.md) - File I/O operations with CSV format
- [Laboratory Work 5](src/lab05/README.md) - JSON and CSV data conversion
- [Laboratory Work 6](src/lab06/README.md) - Command-line interface tools
- [Laboratory Work 7](src/lab07/README.md) - Testing with pytest
- [Laboratory Work 8](src/lab08/README.md) - Object-oriented programming with dataclasses and serialization

## Project Structure

```
python_labs/
├─ README.md                        # Main report
├─ src/
│   ├─ lib                          # Shared library modules
│   ├─ lab01/                       # Lab 1: Basic Python
│   ├─ lab02/                       # Lab 2: Arrays and matrices
│   ├─ lab03/                       # Lab 3: Text processing
│   ├─ lab04/                       # Lab 4: File I/O with CSV
│   ├─ lab05/                       # Lab 5: JSON and CSV conversion
│   ├─ lab06/                       # Lab 6: CLI tools
│   ├─ lab07/                       # Lab 7: Testing
│   └─ lab08/                       # Lab 8: OOP with dataclasses
├─ data/                            # Data files for labs
├─ images/                          # Screenshots and images
└─ tests/                           # Test files
```

## Requirements

- Python 3.11 or higher
- Required packages listed in `requirements.txt`

## Installation

```bash
pip install -r requirements.txt
```

## Running Tests

```bash
pytest
```

## Code Quality

The project uses Black and Ruff for code formatting and linting:

```bash
# Check code formatting
black --check .

# Check code linting
ruff check .
