from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from ..config import GRAPH_EDGES, GRAPH_NODES
from ..schemas.graph import GraphEdge, GraphNode, GraphResponse


@lru_cache(maxsize=1)
def load_graph() -> GraphResponse:
    nodes = [
        GraphNode(
            id=item["id"],
            type=item["type"],
            label=item["label"],
            name=item.get("properties", {}).get("name"),
        )
        for item in _read_jsonl(GRAPH_NODES)
    ]
    edges = [
        GraphEdge(source=item["source"], target=item["target"], type=item["type"])
        for item in _read_jsonl(GRAPH_EDGES)
    ]
    return GraphResponse(nodes=nodes, edges=edges)


def graph_for_entity(entity_id: str, depth: int = 1) -> GraphResponse:
    graph = load_graph()
    selected = {entity_id}
    for _ in range(max(depth, 1)):
        current_layer = set(selected)
        for edge in graph.edges:
            if edge.source in current_layer or edge.target in current_layer:
                selected.add(edge.source)
                selected.add(edge.target)
    return GraphResponse(
        nodes=[node for node in graph.nodes if node.id in selected],
        edges=[edge for edge in graph.edges if edge.source in selected and edge.target in selected],
    )


def graph_for_subject(subject_code: str, depth: int = 1) -> GraphResponse:
    graph = load_graph()
    normalized = subject_code.upper()
    subject_id = next(
        (node.id for node in graph.nodes if node.type == "Subject" and node.label.upper() == normalized),
        f"subject:{subject_code}",
    )
    prerequisite_edges = [
        edge
        for edge in graph.edges
        if edge.type == "REQUIRES_PREREQUISITE"
        and edge.source.startswith("subject:")
        and edge.target.startswith("subject:")
    ]
    selected = {subject_id}
    for upstream in (True, False):
        frontier = {subject_id}
        for _ in range(max(depth, 1)):
            next_frontier: set[str] = set()
            for edge in prerequisite_edges:
                if upstream and edge.target in frontier:
                    next_frontier.add(edge.source)
                elif not upstream and edge.source in frontier:
                    next_frontier.add(edge.target)
            selected.update(next_frontier)
            frontier = next_frontier
    return GraphResponse(
        nodes=[node for node in graph.nodes if node.id in selected],
        edges=[
            edge
            for edge in prerequisite_edges
            if edge.source in selected and edge.target in selected
        ],
    )


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
