from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends

from ..db import get_db
from ..schemas.retrieval import RetrieveRequest, RetrieveResponse
from ..services.retrieval import retrieve


router = APIRouter(prefix="/api", tags=["retrieval"])


@router.post("/retrieve", response_model=RetrieveResponse)
async def retrieve_endpoint(request: RetrieveRequest, db: sqlite3.Connection = Depends(get_db)) -> RetrieveResponse:
    return retrieve(db, request.query)
