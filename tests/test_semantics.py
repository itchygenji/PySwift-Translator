from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from pyswift import translate_source


def compile_and_run_swift(source: str, tmp_path: Path, *, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    if not shutil.which("swiftc"):
        pytest.skip("swiftc is not installed")
    result = translate_source(source, embed_runtime=True)
    errors = [d.format("program.py") for d in result.diagnostics if d.level == "error"]
    assert not errors, "\n".join(errors)
    swift_file = tmp_path / "program.swift"
    executable = tmp_path / ("program.exe" if sys.platform == "win32" else "program")
    swift_file.write_text(result.swift, encoding="utf-8")
    subprocess.run(
        ["swiftc", str(swift_file), "-o", str(executable)],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=timeout,
    )
    return subprocess.run(
        [str(executable)],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=timeout,
        cwd=tmp_path,
    )


def run_python(
    source: str,
    tmp_path: Path,
    *,
    timeout: int = 30,
) -> subprocess.CompletedProcess[str]:

    program = tmp_path / "program.py"
    program.write_text(source, encoding="utf-8")

    env = os.environ.copy()
    env["PYTHONIOENCODING"] = "utf-8"
    env["PYTHONUTF8"] = "1"

    return subprocess.run(
        [sys.executable, str(program)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        encoding="utf-8",
        env=env,
        timeout=timeout,
        check=True,
    )


@pytest.mark.swift
def test_core_semantics_match_python(tmp_path: Path):
    source = r'''
import json

GLOBAL = 7

def read_global():
    return GLOBAL

def block_scope(flag):
    if flag:
        x = 11
    else:
        x = 12
    for i in [1, 2]:
        y = i
    return x + y

class Greeter:
    def __init__(self, name="world", punctuation="!"):
        self.name = name
        self.punctuation = punctuation

    def greet(self, prefix="Hello"):
        return prefix + " " + self.name + self.punctuation

print("global", read_global())
print("scope", block_scope(True))
print("slice", [1, 2, 3, 4][::-1])
print("slice2", [0, 1, 2, 3, 4][4:0:-2])
print("mod", -3 % 2, 3 % -2)
print("sorted", sorted([10, 2, 1]))
values = [10, 2, 1]
values.sort(reverse=True)
print("sort-method", values)
print("minmax", min(["z", "a", "m"]), max(["z", "a", "m"]))
print("equality", 1 == 1.0, True == 1)
print("unicode", "héllo ☃")
name = "世界"
print(f"hello {name} ☃")
g = Greeter(punctuation="?", name="Swift")
print("kw", g.greet(prefix="Hi"))
payload = {"name": "Swift", "values": [1, 2], "ok": True, "none": None}
text = json.dumps(payload)
loaded = json.loads(text)
print("json", loaded["name"], loaded["ok"], loaded["none"])
'''
    python_run = run_python(source, tmp_path)
    swift_run = compile_and_run_swift(source, tmp_path)
    assert swift_run.stdout == python_run.stdout


@pytest.mark.swift
def test_global_assignment_from_function_matches_python(tmp_path: Path):
    source = '''
x = 1

def change():
    global x
    x = 5

change()
print(x)
'''
    assert compile_and_run_swift(source, tmp_path).stdout == run_python(source, tmp_path).stdout


@pytest.mark.swift
def test_file_readline_advances_like_python(tmp_path: Path):
    source = '''
with open("lines.txt", "w") as f:
    f.write("one\\ntwo\\n")

with open("lines.txt", "r") as f:
    print(f.readline(), end="")
    print(f.readline(), end="")
'''
    python_run = run_python(source, tmp_path)
    # Python created the file; remove it so Swift performs the whole scenario itself.
    (tmp_path / "lines.txt").unlink()
    swift_run = compile_and_run_swift(source, tmp_path)
    assert swift_run.stdout == python_run.stdout == "one\ntwo\n"


@pytest.mark.swift
def test_multiprocessing_pool_can_read_module_globals(tmp_path: Path):
    source = '''
import multiprocessing as mp

FACTOR = 3

def worker(x):
    return x * FACTOR

if __name__ == "__main__":
    with mp.Pool(processes=2) as pool:
        print(pool.map(worker, [1, 2, 3]))
'''
    python_run = run_python(source, tmp_path, timeout=30)
    swift_run = compile_and_run_swift(source, tmp_path, timeout=30)
    assert swift_run.stdout == python_run.stdout


@pytest.mark.swift
def test_multiprocessing_worker_large_stdout_does_not_deadlock(tmp_path: Path):
    source = '''
import multiprocessing as mp

def worker():
    print("x" * 100000)
    return 1

if __name__ == "__main__":
    p = mp.Process(target=worker, args=())
    p.start()
    p.join()
    print("done")
'''
    completed = compile_and_run_swift(source, tmp_path, timeout=30)
    assert completed.stdout.endswith("done\n")
    assert len(completed.stdout) >= 100001
