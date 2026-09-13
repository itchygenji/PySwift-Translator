.PHONY: test install smoke clean

install:
	python -m pip install -e ".[dev]"

test:
	pytest

smoke:
	pyswift examples/basic.py --package .build/basic --build
	.build/basic/.build/debug/basic

clean:
	rm -rf .build build dist *.egg-info src/*.egg-info .pytest_cache
