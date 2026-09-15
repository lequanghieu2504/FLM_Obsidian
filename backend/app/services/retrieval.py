from __future__ import annotations

import re
import sqlite3

from ..schemas.retrieval import RetrieveResponse
from .search import search_chunks


_SUBJECT_PATTERN = re.compile(r"\b[A-Z]{2,8}\d{3}[A-Za-z]?\b", re.IGNORECASE)


def retrieve(db: sqlite3.Connection, query: str) -> RetrieveResponse:
    subject_code = _detect_subject(query)
    intent = _detect_intent(query)
    session_number = _detect_session_number(query)
    search_text = _search_text(query, subject_code, intent, session_number)
    results = search_chunks(
        db,
        search_text,
        subject_code=subject_code,
        section=intent,
        session_number=session_number,
        limit=6,
    )
    return RetrieveResponse(query=query, subject_code=subject_code, intent=intent, results=results)


def _detect_subject(query: str) -> str | None:
    match = _SUBJECT_PATTERN.search(query)
    return match.group(0).upper() if match else None


def _detect_intent(query: str) -> str | None:
    lower = query.lower()
    if "prerequisite" in lower or "pre-requisite" in lower:
        return "prerequisite"
    if "tín chỉ" in lower or "tin chi" in lower or "credit" in lower:
        return "general_information"
    if any(token in lower for token in ("assessment", "final", "thi", "cuối kỳ", "cuoi ky", "grade", "%")):
        return "assessment"
    if "outcome" in lower or "clo" in lower:
        return "learning_outcomes"
    if "schedule" in lower or "session" in lower or "hiragana" in lower or "buổi" in lower or "buoi" in lower:
        return "schedule"
    if "material" in lower or "book" in lower:
        return "materials"
    return None


def _detect_session_number(query: str) -> int | None:
    match = re.search(r"\b(?:session|buổi|buoi)\s+(\d+)\b", query, re.IGNORECASE)
    return int(match.group(1)) if match else None


def _search_text(query: str, subject_code: str | None, intent: str | None, session_number: int | None) -> str:
    if session_number is not None:
        return ""
    if intent == "schedule" and "hiragana" in query.lower():
        return "hiragana"
    if subject_code and intent and intent != "schedule":
        return ""
    text = query
    if subject_code:
        text = re.sub(re.escape(subject_code), "", text, flags=re.IGNORECASE)
    if intent:
        text = re.sub(intent.replace("_", " "), "", text, flags=re.IGNORECASE)
    return text.strip()
