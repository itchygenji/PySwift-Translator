from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from . import __version__
from .project import build_swift_package
from .translator import Translator


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="pyswift", description="Translate Python source to Swift")
    p.add_argument("input", nargs="?", type=Path, help="Python source file")
    p.add_argument("-o", "--output", type=Path, help="Swift output file")
    p.add_argument("--package", type=Path, metavar="DIR", help="Generate a buildable Swift Package")
    p.add_argument("--product-name", help="Executable/Swift package target name")
    p.add_argument("--standalone", action="store_true", help="Embed the compatibility runtime in one .swift file")
    p.add_argument("--check", action="store_true", help="Translate and report diagnostics without writing output")
    p.add_argument("--build", action="store_true", help="Build generated Swift package after translation")
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return p


def print_diagnostics(diags, filename: str) -> None:
    for d in diags:
        print(d.format(filename), file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if not args.input:
        parser().error("input Python file is required")
    if not args.input.exists():
        print(f"pyswift: input file not found: {args.input}", file=sys.stderr)
        return 2

    if args.package:
        output_dir, diags = build_swift_package(args.input, args.package, args.product_name)
        print_diagnostics(diags, str(args.input))
        if any(d.level == "error" for d in diags):
            print("pyswift: package generated with translation errors; review TODO markers/diagnostics", file=sys.stderr)
            return 1
        print(f"Generated Swift package: {output_dir}")
        if args.build:
            if not shutil.which("swift"):
                print("pyswift: Swift toolchain not found on PATH", file=sys.stderr)
                return 3
            completed = subprocess.run(["swift", "build"], cwd=output_dir)
            return completed.returncode
        return 0

    result = Translator(str(args.input)).translate_file(args.input, embed_runtime=args.standalone)
    print_diagnostics(result.diagnostics, str(args.input))
    if args.check:
        return 0 if result.ok else 1
    output = args.output or args.input.with_suffix(".swift")
    output.write_text(result.swift, encoding="utf-8")
    print(f"Wrote: {output}")
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
