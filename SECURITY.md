# Security Policy

PySwift Translator consumes source code and emits source code. Treat both the input Python program and the generated Swift program as executable code.

## Reporting a vulnerability

Please report security issues privately through GitHub's security reporting features when available rather than opening a public issue with exploit details.

## Security boundaries

- PySwift does not sandbox the Python source being translated.
- Translating source does not require executing that source, but tests/examples may execute Python and generated Swift.
- Generated Swift should be reviewed and tested before running code from an untrusted source.
- Third-party Python packages are not automatically translated or vendored.
- The multiprocessing runtime launches child copies of the generated executable and passes encoded arguments on the command line.
