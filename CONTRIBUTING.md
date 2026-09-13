# Contributing

Thanks for improving PySwift Translator.

## Development setup

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
pytest
```

## Adding language support

1. Add or change the AST lowering in `src/pyswift/translator.py`.
2. Add narrowly scoped runtime behavior to `src/pyswift/templates/PyRuntime.swift` only when Python semantics require it.
3. Add a unit test for generated code/diagnostics.
4. Add a Python-vs-Swift differential test when behavior can be executed deterministically.
5. Update `docs/COMPATIBILITY.md` and the README if the public support surface changes.

Never silently discard a Python construct when doing so can materially change behavior. Emit a warning or error instead.
