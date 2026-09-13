from pathlib import Path

from pyswift.cli import main


def test_check_returns_nonzero_for_unsupported_syntax(tmp_path: Path):
    source = tmp_path / "bad.py"
    source.write_text("assert True\n", encoding="utf-8")
    assert main([str(source), "--check"]) == 1


def test_cli_writes_standalone_file(tmp_path: Path):
    source = tmp_path / "hello.py"
    output = tmp_path / "hello.swift"
    source.write_text('print("hello")\n', encoding="utf-8")
    assert main([str(source), "-o", str(output), "--standalone"]) == 0
    text = output.read_text(encoding="utf-8")
    assert "public indirect enum PyValue" in text
    assert "pyPrint" in text
