import shutil
import subprocess
from pathlib import Path

import pytest

from pyswift.project import build_swift_package


@pytest.mark.swift
def test_generated_swift_builds_and_runs(tmp_path: Path):
    if not shutil.which("swift"):
        pytest.skip("Swift toolchain is not installed")
    source = tmp_path / "program.py"
    source.write_text(
        '''\ndef square(x):\n    return x * x\n\nfor n in [1, 2, 3]:\n    print(n, square(n))\n''',
        encoding="utf-8",
    )
    package = tmp_path / "SwiftProgram"
    _, diagnostics = build_swift_package(source, package, "SwiftProgram")
    assert not [d for d in diagnostics if d.level == "error"]
    subprocess.run(["swift", "build"], cwd=package, check=True, capture_output=True, text=True)
    exe = package / ".build" / "debug" / "SwiftProgram"
    completed = subprocess.run([str(exe)], check=True, capture_output=True, text=True)
    assert completed.stdout == "1 1\n2 4\n3 9\n"


@pytest.mark.swift
def test_multiprocessing_pool_builds_and_runs(tmp_path: Path):
    if not shutil.which("swift"):
        pytest.skip("Swift toolchain is not installed")
    source = tmp_path / "mp.py"
    source.write_text(
        '''\nimport multiprocessing as mp\n\ndef worker(x):\n    return x * x\n\nif __name__ == "__main__":\n    with mp.Pool(processes=2) as pool:\n        print(pool.map(worker, [1, 2, 3, 4]))\n''',
        encoding="utf-8",
    )
    package = tmp_path / "SwiftMP"
    _, diagnostics = build_swift_package(source, package, "SwiftMP")
    assert not [d for d in diagnostics if d.level == "error"]
    subprocess.run(["swift", "build"], cwd=package, check=True, capture_output=True, text=True)
    exe = package / ".build" / "debug" / "SwiftMP"
    completed = subprocess.run([str(exe)], check=True, capture_output=True, text=True)
    assert "[1, 4, 9, 16]" in completed.stdout
