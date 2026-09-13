# Testing and Release Checklist

## Test layers

### 1. Translator/unit tests

These tests inspect generated code and diagnostics without requiring Swift. They cover known-call argument validation, unsupported syntax diagnostics, CLI behavior, and expected lowering patterns.

```bash
pytest -m "not swift"
```

### 2. Swift compile/run integration tests

Tests marked `swift` generate standalone Swift, compile it with `swiftc`, run the binary, and verify the output.

```bash
pytest -m swift
```

### 3. Differential semantic tests

Representative Python programs are executed twice: once with CPython and once after translation/Swift compilation. Stdout is compared exactly for deterministic cases.

Covered regression areas include:

- module globals read from functions;
- assignments that cross Python `if`/`for` block boundaries;
- negative-step slicing;
- negative modulo;
- numeric sorting and string min/max;
- bool/int/float equality;
- Unicode strings/f-strings;
- constructor and method keyword arguments;
- JSON round-trips;
- advancing `readline()` behavior;
- multiprocessing workers reading module globals.

### 4. Multiprocessing stress regression

A worker writes more than a typical OS pipe buffer before returning. The test ensures the translated parent drains stdout before waiting so `join()` does not deadlock.

### 5. Packaging smoke test

Before release:

```bash
python -m pip wheel . --no-deps -w dist
python -m venv install-test
```

Then install the wheel into the clean environment and run:

```bash
pyswift --version
pyswift examples/basic.py -o basic.swift --standalone
```

Compile the generated file with `swiftc` where available.

## GitHub Actions

`.github/workflows/test.yml` runs:

- Python unit tests on Linux across Python 3.10-3.13;
- a Windows Python 3.13 smoke/test job;
- a macOS Python 3.13 smoke/test job;
- Swift compile/run integration tests on macOS;
- a package-build/install smoke test.

The local development environment cannot prove other operating systems behave identically. Treat the GitHub Actions run after push as part of the release gate.

## Release gate

Do not publish a tag/PyPI version unless all of the following are true:

- unit tests pass;
- Swift integration tests pass;
- package wheel builds;
- wheel installs in a clean virtual environment;
- `pyswift --version` works from the installed wheel;
- documented compatibility matches the tests;
- no unsupported construct used by release examples is silently discarded;
- GitHub Actions is green for the release commit.
