from __future__ import annotations

from pydantic import BaseModel


class GraphNode(BaseModel):
    id: str
    type: str
    label: str
    name: str | None = None


class GraphEdge(BaseModel):
    source: str
    target: str
    type: str


class GraphResponse(BaseModel):
    nodes: list[GraphNode]
    edges: list[GraphEdge]
