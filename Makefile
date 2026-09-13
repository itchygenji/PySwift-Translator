.PHONY: install test unit swift smoke wheel clean

install:
	python -m pip install -e ".[dev]"

test:
	python -m pytest

unit:
	python -m pytest -m "not swift"

swift:
	python -m pytest -m swift

smoke:
	pyswift examples/basic.py --package .build/basic --build
	.build/basic/.build/debug/basic

wheel:
	python -m pip wheel . --no-deps -w dist

clean:
	rm -rf .build build dist *.egg-info src/*.egg-info .pytest_cache
