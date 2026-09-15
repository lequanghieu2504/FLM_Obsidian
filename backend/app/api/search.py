from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends, Query

from ..db import get_db
from ..schemas.retrieval import SearchResult
from ..services.search import search_chunks


router = APIRouter(prefix="/api/search", tags=["search"])


@router.get("", response_model=list[SearchResult])
async def search(
    q: str = Query(..., min_length=1),
    subject_code: str | None = None,
    section: str | None = None,
    limit: int = Query(8, ge=1, le=50),
    db: sqlite3.Connection = Depends(get_db),
) -> list[SearchResult]:
    return search_chunks(db, q, subject_code=subject_code, section=section, limit=limit)
