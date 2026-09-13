from __future__ import annotations

import re
from pathlib import Path

from .translator import Translator, runtime_source


def safe_product_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if not cleaned or cleaned[0].isdigit():
        cleaned = "PySwiftApp_" + cleaned
    return cleaned


def build_swift_package(input_file: Path, output_dir: Path, product_name: str | None = None) -> tuple[Path, list]:
    product = safe_product_name(product_name or input_file.stem)
    result = Translator(str(input_file)).translate_file(input_file, embed_runtime=False)
    source_dir = output_dir / "Sources" / product
    source_dir.mkdir(parents=True, exist_ok=True)
    (source_dir / "PyRuntime.swift").write_text(runtime_source(), encoding="utf-8")
    (source_dir / "main.swift").write_text(result.swift, encoding="utf-8")
    package = f'''// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{product}",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "{product}", targets: ["{product}"])],
    targets: [.executableTarget(name: "{product}")]
)
'''
    (output_dir / "Package.swift").write_text(package, encoding="utf-8")
    return output_dir, result.diagnostics
