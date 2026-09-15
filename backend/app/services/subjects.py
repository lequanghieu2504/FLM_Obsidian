from __future__ import annotations

import json
import sqlite3

from ..schemas.subjects import ScheduleItem, SubjectDetail, SubjectList, SubjectSummary, SyllabusSummary


def list_subjects(db: sqlite3.Connection, q: str = "", page: int = 1, page_size: int = 50) -> SubjectList:
    page = max(page, 1)
    page_size = min(max(page_size, 1), 200)
    args: list[object] = []
    where = ""
    if q.strip():
        where = "WHERE UPPER(code) LIKE ? OR LOWER(name) LIKE ?"
        args.extend([f"%{q.strip().upper()}%", f"%{q.strip().lower()}%"])
    total = db.execute(f"SELECT COUNT(*) FROM subjects {where}", args).fetchone()[0]
    rows = db.execute(
        f"SELECT code, name FROM subjects {where} ORDER BY code LIMIT ? OFFSET ?",
        [*args, page_size, (page - 1) * page_size],
    )
    return SubjectList(
        items=[SubjectSummary(code=row["code"], name=row["name"]) for row in rows],
        page=page,
        page_size=page_size,
        total=total,
    )


def resolve_subject_code(db: sqlite3.Connection, subject_code: str) -> str | None:
    row = db.execute("SELECT code FROM subjects WHERE UPPER(code) = ? LIMIT 1", [subject_code.upper()]).fetchone()
    return row["code"] if row else None


def get_subject(db: sqlite3.Connection, subject_code: str) -> SubjectDetail | None:
    code = resolve_subject_code(db, subject_code)
    if code is None:
        return None
    subject = db.execute("SELECT code, name FROM subjects WHERE code = ?", [code]).fetchone()
    syllabi = [_syllabus_summary(row, db) for row in db.execute(_SYLLABI_SQL, [code])]
    return SubjectDetail(
        code=subject["code"],
        name=subject["name"],
        syllabi=syllabi,
        learning_outcomes=_json_chunk_records(db, code, "learning_outcomes"),
        assessment=_json_chunk_records(db, code, "assessment"),
        materials=_json_chunk_records(db, code, "materials"),
    )


def get_schedule(db: sqlite3.Connection, subject_code: str, session_number: int | None = None) -> list[ScheduleItem] | None:
    code = resolve_subject_code(db, subject_code)
    if code is None:
        return None
    args: list[object] = [code]
    sql = """
        SELECT subject_code, syllabus_id, session_number, title, content
        FROM chunks
        WHERE subject_code = ? AND section = 'schedule'
    """
    if session_number is not None:
        sql += " AND session_number = ?"
        args.append(session_number)
    sql += " ORDER BY syllabus_id DESC, session_number"
    return [
        ScheduleItem(
            subject_code=row["subject_code"],
            syllabus_id=row["syllabus_id"],
            session_number=row["session_number"],
            title=row["title"],
            content=row["content"],
        )
        for row in db.execute(sql, args)
    ]


_SYLLABI_SQL = """
    SELECT syllabus_id, subject_code, subject_name, syllabus_name, active, approved,
           decision, description, source_path
    FROM syllabi
    WHERE subject_code = ?
    ORDER BY syllabus_id DESC
"""


def _syllabus_summary(row: sqlite3.Row, db: sqlite3.Connection) -> SyllabusSummary:
    general = db.execute(
        "SELECT content FROM chunks WHERE syllabus_id = ? AND section = 'general_information' LIMIT 1",
        [row["syllabus_id"]],
    ).fetchone()
    fields = _parse_general(general["content"] if general else "")
    return SyllabusSummary(
        syllabus_id=row["syllabus_id"],
        subject_code=row["subject_code"],
        subject_name=row["subject_name"],
        syllabus_name=row["syllabus_name"],
        active=_bool(row["active"]),
        approved=_bool(row["approved"]),
        decision=row["decision"],
        description=row["description"],
        source_path=row["source_path"],
        credits=fields.get("NoCredit"),
        degree_level=fields.get("Degree Level"),
        time_allocation=fields.get("Time Allocation"),
        prerequisite=fields.get("Pre-Requisite"),
    )


def _json_chunk_records(db: sqlite3.Connection, subject_code: str, section: str) -> list[dict[str, str]]:
    row = db.execute(
        "SELECT content FROM chunks WHERE subject_code = ? AND section = ? ORDER BY syllabus_id DESC LIMIT 1",
        [subject_code, section],
    ).fetchone()
    if not row:
        return []
    records = []
    for line in row["content"].splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            records.append({str(key): str(val) for key, val in value.items()})
    return records


def _parse_general(content: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in content.splitlines():
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return fields


def _bool(value: object) -> bool | None:
    if value is None:
        return None
    return bool(value)
