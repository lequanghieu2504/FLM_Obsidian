from __future__ import annotations

from fastapi import APIRouter, Query

from ..schemas.graph import GraphResponse
from ..services.graph import graph_for_entity, graph_for_subject, load_graph


router = APIRouter(prefix="/api/graph", tags=["graph"])


@router.get("", response_model=GraphResponse)
async def graph(limit: int = Query(1500, ge=1, le=10000)) -> GraphResponse:
    data = load_graph()
    return GraphResponse(nodes=data.nodes[:limit], edges=data.edges[:limit])


@router.get("/subject/{subject_code}", response_model=GraphResponse)
async def subject_graph(subject_code: str, depth: int = Query(1, ge=1, le=3)) -> GraphResponse:
    return graph_for_subject(subject_code, depth=depth)


@router.get("/{entity_id:path}", response_model=GraphResponse)
async def entity_graph(entity_id: str, depth: int = Query(1, ge=1, le=3)) -> GraphResponse:
    return graph_for_entity(entity_id, depth=depth)
