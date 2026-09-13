# Architecture

## Design goals

PySwift Translator is structured as a compiler front end plus a compatibility runtime, not as regex/text substitution. The priorities are explicit semantics, predictable diagnostics, buildable Swift, testability, and incremental language support.

## Translation pipeline

`Translator.translate()` parses source with `ast.parse()`. `SwiftEmitter.pre_scan()` records imports, top-level functions, translated classes, constructor/method signatures, and defaults before code generation.

A second lightweight scope scan records Python bindings. This matters because Python function/module variables are not block-scoped, while Swift variables declared inside `if`/`for` blocks are. PySwift hoists supported bindings to the enclosing Python-equivalent scope and then emits assignments inside the translated block.

The emitter then lowers statements/expressions to Swift. Dynamic Python-compatible values use `PyValue`; translated class instances and runtime objects (`PyFile`, `PyProcess`, `PyPool`) use native Swift reference types tracked by the emitter's symbol-kind table.

Package generation places the generated program and `PyRuntime.swift` in a normal Swift Package layout.

## PyValue

`PyValue` is a Codable Swift enum for:

- `none`
- `bool`
- `int`
- `double`
- `string`
- `list`
- string-keyed `dict`

Runtime operators/helpers reproduce a selected set of Python semantics, including truthiness, bool/int/float equality, numeric/string ordering, negative modulo, indexing, slicing, and common collection/string helpers.

The internal Codable representation is used only for PySwift's child-process protocol. The public `json` adapter uses a separate normal-JSON representation.

## Known-call signature handling

Top-level functions and translated class methods are pre-scanned into `FunctionInfo`. When a call target is known, PySwift:

1. assigns positional arguments to parameters;
2. validates/reorders keyword arguments;
3. fills defaults;
4. reports too many, duplicate, missing, and unexpected arguments.

Unknown calls are not allowed to silently discard keyword arguments.

## Module initialization and multiprocessing

A supported `multiprocessing.Process(target=worker, args=...)` becomes `PyProcess(target: "worker", args: ...)`.

The parent launches the current executable with:

```text
--pyswift-worker <function-name> <base64-json-arguments>
```

The generated executable detects worker mode before running the Python `if __name__ == "__main__"` body. It still executes ordinary module-level initialization first, which allows supported workers to read module globals. The worker target is dispatched afterward.

Worker stdout is drained before `waitUntilExit()` so a child cannot block forever on a full stdout pipe. A private result marker carries the encoded return `PyValue` back to the parent. `PyPool.map` batches child processes and stores decoded results in source order.

## Adding an AST feature

1. Add `expr_<NodeName>` for an expression or `visit_<NodeName>` for a statement.
2. If Python semantics need runtime support, add a narrowly named helper to `PyRuntime.swift`.
3. Add a translator/diagnostic unit test.
4. Add a Python-vs-Swift differential integration test when behavior matters.
5. Update `docs/COMPATIBILITY.md` and the README.

Never rely on `ast.NodeVisitor.generic_visit()` to silently walk an unsupported statement. Unsupported statements should produce diagnostics.

## Adding a library adapter

Small standard-library mappings currently live in `map_module_call()` and `map_module_attribute()`. Larger libraries should move to adapter objects/modules that declare supported calls, attributes, diagnostics, and runtime dependencies.

## Product evolution

The current runtime-backed architecture prioritizes compatibility for a practical subset. A future optimization/type-inference pass can replace stable `PyValue` operations with native `Int`, `Double`, `String`, arrays, dictionaries, structs/classes, and Swift concurrency while retaining the same AST front end and regression corpus.
