# Compatibility

PySwift Translator v0.1.1 intentionally supports a subset of Python. "Supported" means the project has a defined lowering/runtime path and regression coverage for representative cases; it does not mean every edge case of CPython is reproduced.

| Area | Status | Notes |
|---|---|---|
| `None`, bool, int, float, str | Supported | Stored as `PyValue`; several Python numeric equality/order rules are reproduced |
| Unicode strings | Supported | UTF-8 Swift literals and basic f-strings are tested |
| Lists | Supported | Common mutation/index/slice/sort operations |
| Tuples | Partial | Lowered to list-like `PyValue` storage; tuple immutability/type identity is not preserved |
| Dictionaries | Partial | Runtime uses `[String: PyValue]`; non-string keys are string-normalized and insertion order is not guaranteed |
| Sets | Partial | Set literals are currently lowered to lists, so uniqueness semantics are not preserved |
| Arithmetic | Supported subset | `+ - * / // % **`; Python-compatible negative modulo tested |
| Bitwise integer operators | Supported | `& | ^ << >> ~` |
| Comparisons | Supported subset | Numeric/string ordering and Python-like bool/int/float equality; mixed incomparable-type exceptions are not fully modeled |
| `and`, `or`, `not` | Supported | Operand-return behavior for `and`/`or` uses `PyValue` truthiness |
| `if` / `elif` / `else` | Supported | Python-style truthiness |
| `while` | Partial | `while...else` is not fully preserved |
| `for` | Supported subset | Lists, strings, and dictionary-key iteration |
| Python block scope behavior | Improved | Function/module bindings are hoisted so `if`/`for` assignments can survive Swift block scope |
| Functions | Supported subset | Positional/default arguments and validated known keyword calls |
| `global` | Supported subset | Basic module-global reads/writes are tested |
| `nonlocal` | Not yet | Explicit error diagnostic |
| `*args`, `**kwargs`, keyword-only definitions | Not yet | Explicit diagnostics |
| Classes | Partial | Basic class, `__init__`, instance fields, and methods |
| Constructor/method keyword calls | Supported for translated classes | Arguments are reordered and validated against known signatures |
| Inheritance | Partial | Bases are currently omitted with a warning |
| Decorators | Partial | Most are warned and omitted |
| f-strings | Partial | Basic interpolation; advanced conversion/format specs warn |
| Indexing | Supported subset | Lists, strings, dictionaries |
| Slicing | Supported subset | Positive and negative step, including `[::-1]`, tested |
| List comprehensions | Partial | One simple generator target |
| `with open(...)` | Supported subset | Text read/write/append; `read`/`readline`/`write`/`close` |
| `try` / `except` / `finally` | Not yet | Explicit error diagnostic |
| `raise` | Not yet | Explicit error diagnostic / fatal placeholder |
| `assert` | Not yet | Explicit error diagnostic; never silently dropped |
| `async` / `await` | Partial | Currently lowered synchronously with warnings |
| lambdas / first-class functions | Not yet | Requires callable representation in runtime |
| generators / `yield` | Not yet | Explicitly outside current supported surface |
| pattern matching | Not yet | Unsupported statement/expression diagnostics |
| `math` | Partial adapter | `pi`, `sqrt`, `sin`, `cos`, `tan`, `floor`, `ceil` |
| `time` | Partial adapter | `sleep` |
| `random` | Partial adapter | `random`, `randint` |
| `sys` | Partial adapter | `argv` |
| `os` | Partial adapter | `getenv`, `getcwd`, `mkdir`, `makedirs`, `path.exists`, `path.join` |
| `json` | Partial adapter | Normal JSON encode/decode for supported `PyValue` trees; formatting/order may differ |
| `multiprocessing.Process` | Partial | Named top-level target, `PyValue` args/results; real child executable |
| `multiprocessing.Pool.map` | Partial | One iterable, result order preserved |
| third-party Python packages | Not automatic | Require dedicated adapters or manual Swift replacement |

## Important semantic gaps

The runtime deliberately does not pretend to be a complete Python interpreter. In particular, exception types/messages, dictionary insertion order, arbitrary object identity, descriptors, metaclasses, runtime monkey-patching, dynamic import behavior, and C-extension ecosystems are not yet reproduced.

If a Python program depends on one of these areas, treat the generated Swift as a starting point rather than an equivalent build.
