from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from src.config import PROJECT_ROOT
from src.models.graph import Edge, Node
from src.parser.prerequisite_parser import extract_prerequisite_codes


def _iter_syllabi(normalized_dir: Path) -> list[dict[str, Any]]:
    return [
        json.loads(path.read_text(encoding="utf-8"))
        for path in sorted(normalized_dir.glob("*.json"))
        if path.stem.isdigit()
    ]


def _is_inactive(syllabus: dict[str, Any]) -> bool:
    return syllabus.get("active") is False


def build_graph(
    normalized_dir: Path | None = None,
    graph_dir: Path | None = None,
) -> tuple[list[Node], list[Edge]]:
    source = normalized_dir or PROJECT_ROOT / "data/normalized/syllabi"
    destination = graph_dir or PROJECT_ROOT / "data/graph"
    nodes: dict[str, Node] = {}
    edges: list[Edge] = []
    edge_keys: set[tuple[str, str, str]] = set()

    syllabi = [syllabus for syllabus in _iter_syllabi(source) if not _is_inactive(syllabus)]
    subject_codes = {syllabus.get("subject_code", "") for syllabus in syllabi if syllabus.get("subject_code")}

    for syllabus in syllabi:
        subject_code = syllabus.get("subject_code", "")
        if not subject_code:
            continue
        subject_id = f"subject:{subject_code}"
        syllabus_id = syllabus["id"]
        nodes.setdefault(
            subject_id,
            Node(
                id=subject_id,
                type="Subject",
                label=subject_code,
                properties={"code": subject_code, "name": syllabus.get("subject_name", "")},
            ),
        )
        nodes[syllabus_id] = Node(
            id=syllabus_id,
            type="Syllabus",
            label=f"SYL-{syllabus['syllabus_id']}",
            properties=syllabus,
        )
        _append_edge(edges, edge_keys, Edge(source=subject_id, target=syllabus_id, type="HAS_SYLLABUS", properties={}))

        for prerequisite_code in extract_prerequisite_codes(syllabus.get("prerequisite", ""), subject_codes):
            if prerequisite_code == subject_code:
                continue
            prerequisite_id = f"subject:{prerequisite_code}"
            _append_edge(
                edges,
                edge_keys,
                Edge(
                    source=prerequisite_id,
                    target=subject_id,
                    type="REQUIRES_PREREQUISITE",
                    properties={
                        "syllabus_id": syllabus.get("syllabus_id"),
                        "prerequisite_text": syllabus.get("prerequisite", ""),
                    },
                ),
            )

        for material in syllabus.get("materials", []):
            label = material.get("Material") or material.get("Title") or material.get("items", ["Material"])[0]
            material_id = f"material:{label}".replace(" ", "_")
            nodes.setdefault(material_id, Node(id=material_id, type="Material", label=label, properties=material))
            _append_edge(edges, edge_keys, Edge(source=syllabus_id, target=material_id, type="USES_MATERIAL", properties={}))

    destination.mkdir(parents=True, exist_ok=True)
    (destination / "nodes.jsonl").write_text(
        "\n".join(json.dumps(node.to_json(), ensure_ascii=False) for node in nodes.values()) + ("\n" if nodes else ""),
        encoding="utf-8",
    )
    (destination / "edges.jsonl").write_text(
        "\n".join(json.dumps(edge.to_json(), ensure_ascii=False) for edge in edges) + ("\n" if edges else ""),
        encoding="utf-8",
    )
    return list(nodes.values()), edges


def _append_edge(edges: list[Edge], edge_keys: set[tuple[str, str, str]], edge: Edge) -> None:
    key = (edge.source, edge.target, edge.type)
    if key in edge_keys:
        return
    edge_keys.add(key)
    edges.append(edge)
