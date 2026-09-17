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
    if subject_code and intent == "prerequisite":
        reverse_results = search_chunks(
            db,
            query=subject_code,
            subject_code=None,
            section="prerequisite",
            limit=6,
        )
        existing_keys = {(r.subject_code, r.section, r.syllabus_id) for r in results}
        for item in reverse_results:
            key = (item.subject_code, item.section, item.syllabus_id)
            if key not in existing_keys:
                results.append(item)
                existing_keys.add(key)
    return RetrieveResponse(query=query, subject_code=subject_code, intent=intent, results=results)


def _detect_subject(query: str) -> str | None:
    match = _SUBJECT_PATTERN.search(query)
    return match.group(0).upper() if match else None


def _detect_intent(query: str) -> str | None:
    lower = query.lower()
    if any(k in lower for k in ("prerequisite", "pre-requisite", "tiên quyết", "tien quyet", "tiên-quyết", "rớt", "rot", "bị khóa", "bi khoa", "học trước", "hoc truoc", "môn trước", "mon truoc", "điều kiện", "dieu kien")):
        return "prerequisite"
    if any(k in lower for k in ("tín chỉ", "tin chi", "credit", "số tín", "so tin", "mấy tín", "may tin")):
        return "general_information"
    if any(k in lower for k in ("assessment", "final", "thi", "cuối kỳ", "cuoi ky", "grade", "%", "điểm", "diem", "tính điểm", "tinh diem", "trọng số", "trong so", "đánh giá", "danh gia")):
        return "assessment"
    if any(k in lower for k in ("outcome", "clo", "mục tiêu", "muc tieu", "chuẩn đầu ra", "chuan dau ra")):
        return "learning_outcomes"
    if any(k in lower for k in ("schedule", "session", "hiragana", "buổi", "buoi", "lịch trình", "lich trinh", "nội dung", "noi dung", "chương trình", "chuong trinh")):
        return "schedule"
    if any(k in lower for k in ("material", "book", "sách", "sach", "tài liệu", "tai lieu", "giáo trình", "giao trinh")):
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
