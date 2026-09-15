from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import graph, retrieval, search, subjects
from .config import GRAPH_EDGES, GRAPH_NODES, KNOWLEDGE_DB


app = FastAPI(title="FLM Knowledge API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, object]:
    return {
        "status": "ok",
        "knowledge_db": KNOWLEDGE_DB.exists(),
        "graph_nodes": GRAPH_NODES.exists(),
        "graph_edges": GRAPH_EDGES.exists(),
    }


app.include_router(subjects.router)
app.include_router(search.router)
app.include_router(retrieval.router)
app.include_router(graph.router)
