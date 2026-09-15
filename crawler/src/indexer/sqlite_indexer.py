from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from src.config import PROJECT_ROOT


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS subjects (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS syllabi (
    syllabus_id INTEGER PRIMARY KEY,
    subject_code TEXT NOT NULL,
    subject_name TEXT NOT NULL DEFAULT '',
    syllabus_name TEXT NOT NULL DEFAULT '',
    active INTEGER,
    approved INTEGER,
    decision TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    source_path TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (subject_code) REFERENCES subjects(code)
);

CREATE TABLE IF NOT EXISTS curricula (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS relations (
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    type TEXT NOT NULL,
    properties_json TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_code TEXT NOT NULL,
    subject_code_norm TEXT NOT NULL,
    syllabus_id INTEGER,
    section TEXT NOT NULL,
    session_number INTEGER,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL,
    source_path TEXT NOT NULL DEFAULT ''
);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts
USING fts5(subject_code, subject_code_norm, syllabus_id UNINDEXED, section, title, content, source_path UNINDEXED, content='chunks', content_rowid='id');

CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
    INSERT INTO chunks_fts(rowid, subject_code, subject_code_norm, syllabus_id, section, title, content, source_path)
    VALUES (new.id, new.subject_code, new.subject_code_norm, new.syllabus_id, new.section, new.title, new.content, new.source_path);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
    INSERT INTO chunks_fts(chunks_fts, rowid, subject_code, subject_code_norm, syllabus_id, section, title, content, source_path)
    VALUES ('delete', old.id, old.subject_code, old.subject_code_norm, old.syllabus_id, old.section, old.title, old.content, old.source_path);
END;
"""


def _json_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False)


def _is_inactive(syllabus: dict[str, Any]) -> bool:
    return syllabus.get("active") is False


ChunkRow = tuple[str, str, int, str, int | None, str, str, str]


def _chunks(syllabus: dict[str, Any]) -> list[ChunkRow]:
    subject_code = syllabus.get("subject_code", "")
    subject_code_norm = subject_code.upper()
    syllabus_id = int(syllabus["syllabus_id"])
    source_path = f"Syllabi/SYL-{syllabus_id}.md"
    rows: list[ChunkRow] = []
    general = syllabus.get("general_information") or {}
    if general:
        rows.append(
            (
                subject_code,
                subject_code_norm,
                syllabus_id,
                "general_information",
                None,
                "General Information",
                "\n".join(f"{key}: {value}" for key, value in general.items()),
                source_path,
            )
        )
    if "prerequisite" in syllabus:
        rows.append(
            (
                subject_code,
                subject_code_norm,
                syllabus_id,
                "prerequisite",
                None,
                "Prerequisite",
                syllabus.get("prerequisite", ""),
                source_path,
            )
        )
    if syllabus.get("description"):
        rows.append(
            (
                subject_code,
                subject_code_norm,
                syllabus_id,
                "overview",
                None,
                "Overview",
                syllabus["description"],
                source_path,
            )
        )
    for section, key in (
        ("learning_outcomes", "learning_outcomes"),
        ("assessment", "assessments"),
        ("constructive_questions", "constructive_questions"),
        ("materials", "materials"),
    ):
        records = syllabus.get(key) or []
        if records:
            rows.append(
                (
                    subject_code,
                    subject_code_norm,
                    syllabus_id,
                    section,
                    None,
                    section.replace("_", " ").title(),
                    "\n".join(_json_text(record) for record in records),
                    source_path,
                )
            )
    for session in syllabus.get("schedule") or []:
        number_text = str(session.get("Session", "")).strip()
        try:
            session_number = int(number_text)
        except ValueError:
            session_number = None
        title = f"Session {number_text}" if number_text else "Session"
        student_tasks = session.get("Student's Tasks", "")
        content_parts = [
            f"Topic: {session.get('Topic', '')}",
            f"Learning-Teaching Type: {session.get('Learning-Teaching Type', '')}",
            f"LO: {session.get('LO', '')}",
            f"ITU: {session.get('ITU', '')}",
            f"Student Materials: {session.get('Student Materials', '')}",
            f"Student's Tasks: {student_tasks}",
            f"URLs: {session.get('URLs', '')}",
        ]
        rows.append(
            (
                subject_code,
                subject_code_norm,
                syllabus_id,
                "schedule",
                session_number,
                title,
                "\n".join(content_parts),
                source_path,
            )
        )
    return rows


def build_sqlite(
    normalized_dir: Path | None = None,
    db_path: Path | None = None,
) -> Path:
    source = normalized_dir or PROJECT_ROOT / "data/normalized/syllabi"
    database = db_path or PROJECT_ROOT / "data/knowledge.db"
    database.parent.mkdir(parents=True, exist_ok=True)
    if database.exists():
        database.unlink()

    with sqlite3.connect(database) as connection:
        connection.executescript(SCHEMA)
        for path in sorted(source.glob("*.json")):
            if not path.stem.isdigit():
                continue
            syllabus = json.loads(path.read_text(encoding="utf-8"))
            if _is_inactive(syllabus):
                print(
                    f"exclude inactive syllabus {syllabus.get('syllabus_id')} "
                    f"({syllabus.get('subject_code', '')}) from SQLite"
                )
                continue
            subject_code = syllabus.get("subject_code", "")
            if not subject_code:
                continue
            connection.execute(
                "INSERT OR REPLACE INTO subjects(code, name) VALUES (?, ?)",
                (subject_code, syllabus.get("subject_name", "")),
            )
            connection.execute(
                """
                INSERT OR REPLACE INTO syllabi(
                    syllabus_id, subject_code, subject_name, syllabus_name,
                    active, approved, decision, description, source_path
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    int(syllabus["syllabus_id"]),
                    subject_code,
                    syllabus.get("subject_name", ""),
                    syllabus.get("syllabus_name", ""),
                    syllabus.get("active"),
                    syllabus.get("approved"),
                    syllabus.get("decision", ""),
                    syllabus.get("description", ""),
                    syllabus.get("source_path", ""),
                ),
            )
            connection.executemany(
                """
                INSERT INTO chunks(subject_code, subject_code_norm, syllabus_id, section, session_number, title, content, source_path)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                _chunks(syllabus),
            )
        connection.commit()
    return database
