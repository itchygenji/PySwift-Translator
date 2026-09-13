from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class Diagnostic:
    level: str
    message: str
    line: int | None = None
    column: int | None = None

    def format(self, filename: str = "<input>") -> str:
        location = filename
        if self.line is not None:
            location += f":{self.line}"
            if self.column is not None:
                location += f":{self.column + 1}"
        return f"{location}: {self.level}: {self.message}"
