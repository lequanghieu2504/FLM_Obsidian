from __future__ import annotations

import re
import sqlite3

from ..schemas.retrieval import SearchResult


_SUBJECT_RE = re.compile(r"^[A-Z]{2,8}\d{3}[A-Za-z]?$", re.IGNORECASE)


def search_chunks(
    db: sqlite3.Connection,
    query: str,
    subject_code: str | None = None,
    section: str | None = None,
    session_number: int | None = None,
    limit: int = 8,
) -> list[SearchResult]:
    query = query.strip()
    if query:
        return _fts_search(db, query, subject_code, section, session_number, limit)
    return _filtered_chunks(db, subject_code, section, session_number, limit)


def _fts_query(query: str) -> str:
    terms = [
        term
        for term in re.findall(r"[\wĐđ]+", query, flags=re.UNICODE)
        if len(term) > 1 and not _SUBJECT_RE.match(term)
    ]
    return " OR ".join(f'"{term}"' for term in terms) or '""'


def _filters(alias: str, subject_code: str | None, section: str | None, session_number: int | None) -> tuple[list[str], list[object]]:
    where: list[str] = []
    args: list[object] = []
    if subject_code:
        where.append(f"{alias}.subject_code_norm = ?")
        args.append(subject_code.upper())
    if section:
        where.append(f"{alias}.section = ?")
        args.append(section)
    if session_number is not None:
        where.append(f"{alias}.session_number = ?")
        args.append(session_number)
    return where, args


def _fts_search(
    db: sqlite3.Connection,
    query: str,
    subject_code: str | None,
    section: str | None,
    session_number: int | None,
    limit: int,
) -> list[SearchResult]:
    where, args = _filters("c", subject_code, section, session_number)
    where.insert(0, "chunks_fts MATCH ?")
    args.insert(0, _fts_query(query))
    args.append(limit)
    sql = f"""
        SELECT c.subject_code, c.syllabus_id, c.section, c.session_number, c.title,
               c.content, c.source_path,
               snippet(chunks_fts, 5, '[', ']', '...', 20) AS snippet
        FROM chunks_fts
        JOIN chunks c ON c.id = chunks_fts.rowid
        WHERE {' AND '.join(where)}
        ORDER BY bm25(chunks_fts)
        LIMIT ?
    """
    return [_row_to_result(row) for row in db.execute(sql, args)]


def _filtered_chunks(
    db: sqlite3.Connection,
    subject_code: str | None,
    section: str | None,
    session_number: int | None,
    limit: int,
) -> list[SearchResult]:
    where, args = _filters("c", subject_code, section, session_number)
    args.append(limit)
    sql = """
        SELECT c.subject_code, c.syllabus_id, c.section, c.session_number, c.title,
               c.content, c.source_path, NULL AS snippet
        FROM chunks c
    """
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY c.subject_code, c.section, c.session_number LIMIT ?"
    return [_row_to_result(row) for row in db.execute(sql, args)]


def _row_to_result(row: sqlite3.Row) -> SearchResult:
    return SearchResult(
        subject_code=row["subject_code"],
        syllabus_id=row["syllabus_id"],
        section=row["section"],
        session_number=row["session_number"],
        title=row["title"] or "",
        content=row["content"] or "",
        snippet=row["snippet"],
        source_path=row["source_path"] or "",
    )
