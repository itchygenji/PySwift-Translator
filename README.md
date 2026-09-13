# PySwift Translator

PySwift Translator is an AST-based Python-to-Swift source translator intended to turn practical Python programs into buildable Swift executables. It ships with a small Swift compatibility runtime so translated code can preserve Python-style dynamic values, lists, dictionaries, truthiness, slicing, common built-ins, file I/O, selected standard-library calls, and basic multiprocessing behavior.

> **Status:** v0.1.0 alpha. It is a real, installable, tested product skeleton, but it is not a drop-in replacement for CPython. Python and Swift have different type systems, object models, exception models, module systems, metaprogramming capabilities, and concurrency semantics. Unsupported syntax is reported as a diagnostic instead of silently pretending the translation is exact.

## What it does

Given:

```python
import math

def square(x):
    return x * x

values = [1, 2, 3, 4]
print("sqrt:", math.sqrt(16))
for value in values:
    print(value, square(value))
```

PySwift generates Swift that builds as an executable and produces corresponding output.

The translator uses Python's `ast` module rather than regex replacement. This makes control flow, expressions, function definitions, classes, and call structure explicit and gives the project a clean path for adding more language features.

## Installation

Development install:

```bash
python -m venv .venv
source .venv/bin/activate              # Windows: .venv\\Scripts\\activate
pip install -e ".[dev]"
```

Normal install from the project directory:

```bash
pip install .
```

You also need a Swift toolchain if you want to build the generated Swift package. On macOS, install Xcode or the Swift toolchain. On Linux, install Swift from swift.org.

## Quick start

Translate one Python file:

```bash
pyswift examples/basic.py -o basic.swift
```

Create a single standalone Swift source file with the compatibility runtime embedded:

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

Check compatibility without writing an output file:

```bash
pyswift your_program.py --check
```

## Python API

```python
from pyswift import translate_source

source = 'print("hello")\n'
result = translate_source(source, embed_runtime=True)

print(result.swift)
for diagnostic in result.diagnostics:
    print(diagnostic.format("example.py"))
```

## Supported language features

The compatibility surface is intentionally explicit.

| Python feature | Status | Notes |
|---|---|---|
| `print`, `input` | Supported | `sep` and `end` supported for `print` |
| ints, floats, bools, strings, `None` | Supported | Represented by `PyValue` |
| lists, tuples | Supported | Tuples currently lower to list-like `PyValue` storage |
| dictionaries | Supported | Keys are string-normalized in the runtime |
| set literals | Partial | Lowered to lists; uniqueness semantics are not preserved |
| arithmetic | Supported | `+ - * / // % **` |
| bitwise operators | Supported | `& | ^ << >> ~` on integer-like values |
| comparisons | Supported | Includes chained comparisons and `in` / `not in` |
| `and`, `or`, `not` | Supported | Preserves Python-style operand return for `and`/`or` |
| `if` / `elif` / `else` | Supported | Uses Python-style truthiness |
| `while` | Supported | `while...else` is only partial |
| `for` | Supported | Iterates strings, lists, and dictionary keys |
| `break`, `continue`, `pass` | Supported | |
| functions | Supported | Positional/default args and many keyword calls |
| recursion | Supported | |
| `*args`, `**kwargs`, keyword-only defs | Not yet | Emits diagnostics |
| f-strings | Supported | Basic interpolation |
| indexing and slices | Supported | Common positive/negative indexing and slicing |
| list comprehensions | Partial | One generator with a simple name target |
| classes | Partial | Basic classes, `__init__`, instance properties, methods |
| inheritance | Partial | Base classes currently omitted with warning |
| decorators | Partial | Most decorators warn and are omitted |
| `with open(...)` | Supported | Basic text read/write/append |
| `try/except/finally` | Not yet | Explicit diagnostic; requires error-model translation |
| `raise` | Not yet | Emits diagnostic / placeholder |
| `async` / `await` | Partial | Currently lowered synchronously with warnings |
| lambdas / first-class functions | Not yet | Requires callable support in `PyValue` |
| generators / `yield` | Not yet | |
| pattern matching | Not yet | |

### Built-ins currently mapped

`print`, `input`, `len`, `int`, `float`, `str`, `bool`, `abs`, `sum`, `min`, `max`, `round`, `any`, `all`, `sorted`, `reversed`, `range`, `enumerate`, `zip`, `list`, `dict`, and `open`.

### Common methods currently mapped

Lists: `append`, `extend`, `insert`, `pop`, `remove`, `reverse`, `sort`.

Strings: `upper`, `lower`, `strip`, `replace`, `startswith`, `endswith`, `split`, `find`.

Dictionaries: `keys`, `values`, `items`, `get`.

Files: `read`, `readline`, `write`, `close`.

## Standard-library mappings

Current mappings include selected functionality from:

- `math`: `pi`, `sqrt`, `sin`, `cos`, `tan`, `floor`, `ceil`
- `time`: `sleep`
- `random`: `random`, `randint`
- `sys`: `argv`
- `os`: `getenv`, `getcwd`, `mkdir`, `makedirs`, `path.exists`, `path.join`
- `json`: `dumps`, `loads` for `PyValue` data
- `multiprocessing`: `Process`, `Pool.map`

Unknown imports are preserved as diagnostics rather than guessed.

## Multiprocessing

PySwift does **not** silently translate Python processes into threads. For the supported `multiprocessing` subset, the generated executable launches child copies of itself with a hidden worker invocation protocol.

Example:

```python
import multiprocessing as mp

def worker(x):
    print("worker", x)
    return x * x

if __name__ == "__main__":
    p = mp.Process(target=worker, args=(5,))
    p.start()
    p.join()

    with mp.Pool(processes=2) as pool:
        results = pool.map(worker, [1, 2, 3, 4])
        print(results)
```

Supported multiprocessing assumptions in v0.1:

- Worker targets must be named top-level functions.
- Worker arguments/results must be representable by `PyValue` and therefore JSON-serializable by the runtime.
- `Pool.map` supports one iterable.
- Shared memory, managers, queues, locks, pipes, custom process contexts, and daemon semantics are future work.

## Architecture

```text
Python source
   |
   v
Python ast.parse()
   |
   v
SwiftEmitter
   |---- diagnostics for unsupported/partial constructs
   |
   +---- generated main.swift
   |
   +---- PyRuntime.swift compatibility layer
              |
              v
         Swift Package / swiftc
              |
              v
          native executable
```

The translator is split into three main pieces:

1. **Front end** — CPython's AST parser validates Python syntax and provides a structured tree.
2. **Emitter** — `SwiftEmitter` converts supported AST nodes into Swift and tracks variable kinds needed for files, classes, and multiprocessing objects.
3. **Compatibility runtime** — `PyValue` and helper functions preserve dynamic behavior that would otherwise be awkward or lossy in idiomatic Swift.

See `docs/ARCHITECTURE.md` for extension details.

## Diagnostics philosophy

A source translator is dangerous if it generates plausible-looking but semantically wrong code. PySwift therefore distinguishes:

- `warning`: translation was produced, but behavior may not be identical.
- `error`: construct is unsupported or cannot be translated safely.

The CLI exits nonzero when translation errors exist.

## Testing

Run the Python unit tests:

```bash
pytest
```

The integration tests compile generated Swift when `swiftc` is available.

Manual end-to-end examples:

```bash
pyswift examples/basic.py --package /tmp/basic --build
/tmp/basic/.build/debug/basic

pyswift examples/multiprocessing_demo.py --package /tmp/mp --build
/tmp/mp/.build/debug/multiprocessing_demo
```

## Packaging and release

The repository includes modern `pyproject.toml` packaging and a console entry point. A normal release flow is:

```bash
python -m pip install --upgrade build twine
python -m build
twine check dist/*
```

Before a public v1.0 release, add semantic-equivalence test corpora, macOS/Linux CI for generated Swift, fuzz tests for AST combinations, and explicit compatibility versioning for `PyRuntime.swift`.

## Important limitations

This project can translate a meaningful subset of Python, but no source-to-source translator can automatically make **all** Python programs equivalent Swift programs without either embedding a Python interpreter or reproducing most of Python's runtime. Features such as runtime monkey-patching, metaclasses, arbitrary descriptors, C-extension packages, dynamic imports, reflection-heavy frameworks, exception subtleties, generators, and ecosystem-specific libraries require dedicated lowering rules or a compatibility layer.

For production use, treat generated Swift as generated source that must pass tests against the original Python program. The long-term product path is to grow the supported AST surface and library adapters while keeping unsupported behavior explicit.

## Roadmap

Near-term priorities:

1. `try` / `except` / `finally` and a Python-compatible error wrapper.
2. First-class callable `PyValue`, lambdas, callbacks, `map`/`filter`.
3. Multi-module Python project translation and import graph handling.
4. Better class inheritance, protocols, dataclasses, properties, and decorators.
5. Generators and iterator protocol.
6. `asyncio` to Swift concurrency lowering.
7. More `multiprocessing` primitives.
8. Pluggable standard-library / third-party package adapters.
9. Source maps from Swift diagnostics back to Python lines.
10. Differential Python-vs-Swift execution tests.

## License

MIT. See `LICENSE`.
