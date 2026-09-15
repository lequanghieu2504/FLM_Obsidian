from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class Node:
    id: str
    type: str
    label: str
    properties: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    type: str
    properties: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        return asdict(self)

