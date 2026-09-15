from __future__ import annotations

from pydantic import BaseModel


class SearchResult(BaseModel):
    subject_code: str
    syllabus_id: int | None
    section: str
    session_number: int | None
    title: str
    content: str
    snippet: str | None = None
    source_path: str = ""


class RetrieveRequest(BaseModel):
    query: str


class RetrieveResponse(BaseModel):
    query: str
    subject_code: str | None
    intent: str | None
    results: list[SearchResult]
