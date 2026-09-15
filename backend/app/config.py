from __future__ import annotations

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"
KNOWLEDGE_DB = DATA_DIR / "knowledge.db"
GRAPH_NODES = DATA_DIR / "graph" / "nodes.jsonl"
GRAPH_EDGES = DATA_DIR / "graph" / "edges.jsonl"
