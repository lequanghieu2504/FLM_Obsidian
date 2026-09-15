from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup

from src.config import PROJECT_ROOT
from src.models.syllabus import NormalizedSyllabus


GENERAL_KEYS = {
    "syllabus id",
    "syllabus name",
    "course name english",
    "subject code",
    "learning-teaching method",
    "nocredit",
    "degree level",
    "time allocation",
    "pre-requisite",
    "description",
    "studenttasks",
    "tools",
    "scoring scale",
    "decisionno",
    "decisionno mm/dd/yyyy",
    "isapproved",
    "note",
    "is scored",
    "minavgmarktopass",
    "isactive",
    "approveddate",
}


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _header_key(text: str) -> str:
    text = _clean(text).rstrip(":").lower()
    return re.sub(r"\s+", " ", text)


def _field_key(text: str) -> str:
    key = _header_key(text)
    return key.replace(" ", "")


def _bool(value: str) -> bool | None:
    normalized = value.strip().lower()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    return None


def _int(value: str) -> int | None:
    try:
        return int(value.strip())
    except ValueError:
        return None


def _table_rows(table) -> list[list[str]]:
    return [
        [_clean(cell.get_text(" ", strip=True)) for cell in row.select("th,td")]
        for row in table.select("tr")
    ]


def _classify_table(rows: list[list[str]]) -> str | None:
    if not rows:
        return None
    first = [_header_key(cell) for cell in rows[0]]
    first_set = set(first)
    if len(first) == 2 and _header_key(first[0]) in GENERAL_KEYS:
        return "general_information"
    if first == ["no.", "clo name", "clo details"]:
        return "learning_outcomes"
    if {"no.", "category", "type", "part", "weight", "completion criteria"}.issubset(first_set):
        return "assessments"
    if {"session", "topic", "learning-teaching type", "lo", "itu"}.issubset(first_set):
        return "schedule"
    if first == ["no.", "session no", "name", "details"]:
        return "constructive_questions"
    if {"no.", "material description", "author", "publisher"}.issubset(first_set):
        return "materials"
    return None


def _parse_general_information(rows: list[list[str]]) -> dict[str, str]:
    info: dict[str, str] = {}
    for row in rows:
        if len(row) >= 2:
            key = _clean(row[0]).rstrip(":")
            info[key] = _clean(" ".join(row[1:]))
    return info


def _parse_tabular_rows(rows: list[list[str]]) -> list[dict[str, Any]]:
    if not rows:
        return []
    headers = rows[0]
    records: list[dict[str, Any]] = []
    for cells in rows[1:]:
        if not any(cells):
            continue
        padded = cells + [""] * max(0, len(headers) - len(cells))
        records.append(dict(zip(headers, padded[: len(headers)], strict=True)))
    return records


def _classified_tables(soup: BeautifulSoup) -> dict[str, Any]:
    sections: dict[str, Any] = {
        "general_information": {},
        "learning_outcomes": [],
        "assessments": [],
        "schedule": [],
        "constructive_questions": [],
        "materials": [],
    }
    for table in soup.select("table"):
        rows = _table_rows(table)
        section = _classify_table(rows)
        if section is None:
            continue
        if section == "general_information":
            sections[section] = _parse_general_information(rows)
        else:
            sections[section].extend(_parse_tabular_rows(rows))
    return sections


def _info_value(info: dict[str, str], *keys: str) -> str:
    wanted = {_field_key(key) for key in keys}
    for key, value in info.items():
        if _field_key(key) in wanted:
            return value
    return ""


def parse_syllabus_html(
    html: str,
    syllabus_id: int,
    source_path: str,
    index_metadata: dict[str, Any] | None = None,
) -> NormalizedSyllabus:
    metadata = index_metadata or {}
    soup = BeautifulSoup(html, "html.parser")
    sections = _classified_tables(soup)
    info = sections["general_information"]
    subject_code = _info_value(info, "Subject Code") or metadata.get("subject_code", "")
    if not subject_code:
        match = re.search(r"\b[A-Z]{2,4}\d{3}[A-Za-z]?\b", soup.get_text(" ", strip=True))
        subject_code = match.group(0) if match else ""
    parsed_syllabus_id = _int(_info_value(info, "Syllabus ID"))

    return NormalizedSyllabus(
        syllabus_id=parsed_syllabus_id or syllabus_id,
        subject_code=subject_code,
        subject_name=metadata.get("subject_name", ""),
        syllabus_name=_info_value(info, "Syllabus Name") or metadata.get("syllabus_name", ""),
        credits=_int(_info_value(info, "NoCredit")),
        degree_level=_info_value(info, "Degree Level"),
        time_allocation=_info_value(info, "Time Allocation"),
        prerequisite=_info_value(info, "Pre-Requisite"),
        general_information=info,
        active=_bool(_info_value(info, "IsActive")) if _info_value(info, "IsActive") else metadata.get("is_active"),
        approved=_bool(_info_value(info, "IsApproved")) if _info_value(info, "IsApproved") else metadata.get("is_approved"),
        decision=_info_value(info, "DecisionNo", "DecisionNo MM/dd/yyyy") or metadata.get("decision", ""),
        description=_info_value(info, "Description"),
        learning_outcomes=sections["learning_outcomes"],
        assessments=sections["assessments"],
        schedule=sections["schedule"],
        constructive_questions=sections["constructive_questions"],
        materials=sections["materials"],
        source_path=source_path,
    )


def normalize_all(
    raw_dir: Path | None = None,
    syllabi_path: Path | None = None,
    output_dir: Path | None = None,
) -> list[dict[str, Any]]:
    source = raw_dir or PROJECT_ROOT / "data/raw/syllabi"
    index_file = syllabi_path or PROJECT_ROOT / "data/index/syllabi.json"
    destination = output_dir or PROJECT_ROOT / "data/normalized/syllabi"
    metadata_by_id = {
        int(item["syllabus_id"]): item
        for item in json.loads(index_file.read_text(encoding="utf-8"))
    } if index_file.exists() else {}
    destination.mkdir(parents=True, exist_ok=True)
    normalized: list[dict[str, Any]] = []

    for html_file in sorted(source.glob("*.html")):
        syllabus_id = int(html_file.stem)
        parsed = parse_syllabus_html(
            html_file.read_text(encoding="utf-8", errors="replace"),
            syllabus_id=syllabus_id,
            source_path=str(html_file.relative_to(PROJECT_ROOT)),
            index_metadata=metadata_by_id.get(syllabus_id),
        )
        data = parsed.to_dict()
        (destination / f"{syllabus_id}.json").write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        normalized.append(data)
    return normalized
