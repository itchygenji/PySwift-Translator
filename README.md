# PySwift Translator

PySwift Translator is an AST-based Python-to-Swift source translator. It converts a documented subset of Python into buildable Swift and ships a small Swift compatibility runtime for Python-style dynamic values, collections, truthiness, slicing, common built-ins, file I/O, selected standard-library calls, and a basic `multiprocessing` subset.

> **Status: v0.1.1 alpha.** This is an installable and tested compiler project, not a drop-in replacement for CPython. Unsupported or unsafe translations should produce diagnostics instead of being silently ignored. Generated Swift should still be tested against the original Python program before production use.

## What changed in v0.1.1

The hardened release adds regression fixes and tests for several semantic issues found during differential Python-vs-Swift execution testing:

- Python module variables can be read from translated functions.
- Variables assigned in `if`/`for` blocks remain visible in their Python function/module scope.
- Negative-step slices such as `[::-1]` now behave correctly for supported sequences.
- Negative modulo follows Python's sign rules for supported numeric values.
- Numeric sorting is numeric instead of lexicographic; string sorting/min/max use string ordering.
- Numeric equality now handles Python-compatible `bool`/`int`/`float` equality such as `True == 1` and `1 == 1.0`.
- Unicode string literals and basic Unicode f-strings compile as Swift source.
- Known function, constructor, and translated-method keyword arguments are normalized and validated.
- Too many, duplicate, missing, and unexpected known-call arguments produce diagnostics.
- Dictionary literals generate safer Swift syntax.
- `json.dumps`/`json.loads` now use normal JSON values instead of the internal multiprocessing encoding.
- `assert`, `nonlocal`, and other unsupported statements are no longer silently discarded.
- `readline()` advances through a file instead of repeatedly returning the first line.
- Multiprocessing workers run module-level initialization before dispatch, so supported workers can read module globals.
- Worker stdout is drained before waiting, preventing a pipe-buffer deadlock on large worker output.

## Installation

From a clone of this repository:

```bash
python -m venv .venv
```

Activate it:

```bash
# Windows PowerShell / Command Prompt
.venv\Scripts\activate

# Windows Git Bash
source .venv/Scripts/activate

# macOS / Linux
source .venv/bin/activate
```

Then install:

```bash
pip install -e ".[dev]"
```

For a normal local install without development dependencies:

```bash
pip install .
```

A Swift toolchain is required only when you want to compile generated Swift. On macOS, Xcode/Xcode Command Line Tools provide Swift. On Linux, install a compatible Swift toolchain.

## Quick start

Translate one Python file:

```bash
pyswift examples/basic.py -o basic.swift
```

Generate a single standalone Swift file with the compatibility runtime embedded:

```bash
pyswift examples/basic.py -o basic.swift --standalone
swiftc basic.swift -o basic
./basic
```

Generate a Swift Package:

```bash
pyswift examples/basic.py --package Build/basic
cd Build/basic
swift build
swift run
```

Generate and build in one command:

```bash
pyswift examples/basic.py --package Build/basic --build
```

Check compatibility without writing output:

```bash
pyswift your_program.py --check
```

The command exits nonzero when translation errors are reported.

## Python API

```python
from pyswift import translate_source

source = 'print("hello")\n'
result = translate_source(source, embed_runtime=True)

print(result.swift)
for diagnostic in result.diagnostics:
    print(diagnostic.format("example.py"))
```

## Supported surface

The compatibility surface is intentionally explicit. See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) for the detailed table.

Commonly supported areas include:

- scalars: `None`, `bool`, `int`, `float`, `str`
- lists, tuple-like storage, string-keyed dictionaries
- arithmetic, comparisons, truthiness, boolean operators, bitwise integer operations
- `if`/`elif`/`else`, `while`, `for`, `break`, `continue`, `pass`
- functions with positional/default parameters and validated keyword calls
- basic classes, constructors, instance fields, and translated method calls
- indexing and common slices, including negative-step slices
- basic f-strings
- `with open(...)` text file handling
- selected `math`, `time`, `random`, `sys`, `os`, and `json` mappings
- a constrained `multiprocessing.Process` and `Pool.map` implementation using real child processes

Not yet equivalent to general CPython:

- arbitrary third-party packages or C-extension modules
- full exception semantics (`try`/`except`/`finally`, `raise`, `assert`)
- generators/`yield`
- arbitrary first-class functions/lambdas/callbacks
- full inheritance/descriptors/metaclasses/decorators
- complete `asyncio`/Swift concurrency translation
- dynamic imports, monkey-patching, `eval`/`exec`, reflection-heavy frameworks
- all dictionary ordering/key semantics
- every Python numeric/error edge case
- full multiprocessing APIs such as queues, managers, shared memory, locks, pipes, contexts, and daemon semantics

## Multiprocessing model

For the supported subset, PySwift does not replace processes with threads. A translated executable launches child copies of itself with an internal worker protocol.

```python
import multiprocessing as mp

FACTOR = 3

def worker(x):
    return x * FACTOR

if __name__ == "__main__":
    with mp.Pool(processes=2) as pool:
        print(pool.map(worker, [1, 2, 3]))
```

Supported assumptions:

- worker targets are named top-level functions;
- arguments/results are representable by `PyValue`;
- `Pool.map` accepts one iterable;
- module-level initialization runs in child workers before the target is dispatched;
- worker scheduling/output order can differ from Python while result order for `Pool.map` is preserved.

## Testing

Run all tests available on the current machine:

```bash
python -m pytest
```

Run only Python-side/unit tests:

```bash
python -m pytest -m "not swift"
```

Run only compile/execute tests that require `swiftc`:

```bash
python -m pytest -m swift
```

The semantic regression suite does real differential execution:

```text
Python source
   |---------------------> CPython stdout
   |
   +-> PySwift -> Swift -> swiftc -> executable stdout
                                      |
                                      +-> compare
```

The v0.1.1 test suite currently contains 20 tests.

On Windows without a Swift toolchain, the validated result is:

```text
13 passed, 7 skipped
```

The seven skipped tests require `swiftc` and perform real Swift compilation and execution. These tests are intended to run on macOS locally and through the macOS GitHub Actions runner.

The current Windows development checks pass:

```text
pytest: 13 passed, 7 skipped
ruff: All checks passed!
mypy: Success: no issues found in 6 source files
```

The package also successfully builds both distribution formats:

```text
pyswift_translator-0.1.1-py3-none-any.whl
pyswift_translator-0.1.1.tar.gz
```

A release should not be published to PyPI until the GitHub Actions workflow, including the macOS Swift integration tests, is green.

See [docs/TESTING.md](docs/TESTING.md) for the release checklist and test categories.

## Architecture

```text
Python source
   |
   v
ast.parse()
   |
   v
SwiftEmitter
   |---- diagnostics
   |---- scope/signature analysis
   |
   +---- generated Swift
             |
             +---- PyRuntime.swift
                       |
                       v
                 swiftc / SwiftPM
                       |
                       v
                native executable
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Packaging

Build a wheel locally:

```bash
python -m pip wheel . --no-deps -w dist
```

For a release build when `build` and `twine` are installed:

```bash
python -m build
python -m twine check dist/*
```

Do not publish a release to PyPI until the GitHub Actions test workflow is green for the commit/tag being released.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).