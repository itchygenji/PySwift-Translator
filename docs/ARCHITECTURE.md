# Architecture

## Design goals

PySwift Translator is structured as a compiler front end plus a compatibility runtime, not as a sequence of textual substitutions. The priorities are semantic visibility, predictable diagnostics, buildable output, and a codebase that can grow feature-by-feature.

## Translation pipeline

`Translator.translate()` parses Python with `ast.parse()`. `SwiftEmitter.pre_scan()` records top-level functions, classes, and import aliases before code generation. This pre-scan enables function keyword/default argument normalization, class construction, and multiprocessing worker dispatch.

`SwiftEmitter` then visits statements and expressions. Values that need Python-like dynamic behavior are emitted as `PyValue`. Objects with important native Swift behavior, such as `PyFile`, `PyProcess`, `PyPool`, and translated class instances, are tracked with a small symbol-kind table.

Package generation copies the generated program and `PyRuntime.swift` into a standard Swift Package layout.

## PyValue

`PyValue` is a Codable Swift enum containing null, bool, integer, double, string, list, and dictionary cases. Operators and helper functions implement Python-like behavior where practical. Codable support is also used by multiprocessing to carry worker arguments and results across process boundaries.

## Multiprocessing protocol

A supported Python `Process(target=worker, args=...)` becomes `PyProcess(target: "worker", args: ...)`.

The parent launches the current executable with:

```text
--pyswift-worker <function-name> <base64-json-arguments>
```

Generated Swift contains a worker dispatcher that calls known top-level functions. The child encodes the return `PyValue` and emits a private result marker. `PyPool.map` starts batches of child processes, then joins them and returns the decoded results in source order.

## Adding an AST feature

1. Add an `expr_<NodeName>` method for expressions or `visit_<NodeName>` for statements.
2. If Python semantics need runtime support, add a narrowly named helper to `PyRuntime.swift`.
3. Add a translation unit test.
4. Add an integration compile/run test when behavior matters.
5. Update the compatibility table in `README.md`.

Do not silently lower a construct when behavior differs materially. Emit a warning or error.

## Adding a library adapter

Library calls are currently mapped in `map_module_call()` and `map_module_attribute()`. For larger libraries, move mappings into adapter classes so each adapter can declare supported modules, calls, attributes, diagnostics, and required runtime code.

## Product evolution

The current runtime-backed approach optimizes compatibility. A future native-optimization pass can infer stable Swift types and replace `PyValue` operations with direct `Int`, `Double`, `String`, arrays, dictionaries, and typed models while retaining the same AST front end.
