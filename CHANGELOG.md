# Changelog

## 0.1.1 - 2026-09-13

- Hardened module/function scope lowering so Python variables assigned inside supported control-flow blocks remain visible in their Python scope.
- Added module-global access and basic `global` statement support.
- Fixed negative-step slicing including `[::-1]`.
- Fixed Python-style negative modulo for supported numeric values.
- Fixed numeric sorting and string min/max ordering.
- Added Python-like numeric equality across bool/int/float values.
- Fixed Unicode Swift string literal and basic f-string emission.
- Added validated keyword argument handling for known functions, constructors, and translated methods.
- Added diagnostics for too many, duplicate, missing, and unexpected known-call arguments.
- Improved dictionary literal emission.
- Reworked JSON mapping to emit/consume normal JSON values instead of the internal `PyValue` Codable envelope.
- Added explicit diagnostics for `assert`, `nonlocal`, and generic unsupported statements.
- Fixed file `read()`/`readline()` cursor behavior for supported text files.
- Fixed multiprocessing module initialization so supported workers can read module globals.
- Fixed a multiprocessing stdout pipe deadlock by draining output before waiting.
- Preserved parent/worker output order by forwarding worker output through the same unbuffered output path.
- Expanded the suite to 20 tests including differential Python-vs-Swift compile/run regressions and multiprocessing stress coverage.
- Added compatibility/testing documentation, contribution/security docs, `.gitattributes`, and expanded CI/release workflows.

## 0.1.0 - 2026-09-13

- Initial AST-based Python-to-Swift translator.
- Dynamic `PyValue` compatibility runtime.
- Core expressions and control flow.
- Functions with defaults and normalized keyword calls.
- Basic classes and instance state.
- Lists, dictionaries, strings, slicing, comprehensions, and common built-ins.
- Selected `math`, `time`, `random`, `sys`, `os`, and `json` adapters.
- Basic file I/O and `with open(...)` support.
- Real child-process support for `multiprocessing.Process` and `Pool.map`.
- CLI, Swift Package generation, diagnostics, examples, tests, and release metadata.
