from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import yaml

from src.config import PROJECT_ROOT
from src.parser.prerequisite_parser import extract_prerequisite_codes, format_prerequisite_links


def _safe_name(value: str) -> str:
    return re.sub(r"[^\w.-]+", "_", value).strip("_")


def _frontmatter(data: dict[str, Any]) -> str:
    return "---\n" + yaml.safe_dump(data, allow_unicode=True, sort_keys=False) + "---\n\n"


def _table(records: list[dict[str, Any]]) -> str:
    if not records:
        return "_No data captured yet._\n"
    keys = list(dict.fromkeys(key for record in records for key in record.keys()))
    lines = [
        "| " + " | ".join(keys) + " |",
        "| " + " | ".join("---" for _ in keys) + " |",
    ]
    for record in records:
        lines.append("| " + " | ".join(str(record.get(key, "")).replace("\n", " ") for key in keys) + " |")
    return "\n".join(lines) + "\n"


def _is_inactive(syllabus: dict[str, Any]) -> bool:
    return syllabus.get("active") is False


def _links(codes: list[str]) -> str:
    if not codes:
        return "_None captured._\n"
    return "\n".join(f"- [[{code}]]" for code in codes) + "\n"


def _write_syllabus(vault: Path, syllabus: dict[str, Any], prerequisite_codes: list[str]) -> str:
    note_name = f"SYL-{syllabus['syllabus_id']}"
    path = vault / "Syllabi" / f"{note_name}.md"
    subject_link = f"[[{syllabus['subject_code']}]]" if syllabus.get("subject_code") else ""
    prerequisite = syllabus.get("prerequisite", "")
    prerequisite_linked = format_prerequisite_links(prerequisite, prerequisite_codes)
    body = [
        f"# {note_name}",
        "",
        f"Subject: {subject_link}",
        f"Name: {syllabus.get('syllabus_name', '')}",
        f"Credits: {syllabus.get('credits', '')}",
        f"Degree Level: {syllabus.get('degree_level', '')}",
        f"Time Allocation: {syllabus.get('time_allocation', '')}",
        f"Prerequisite: {prerequisite_linked}",
        f"Active: {syllabus.get('active', '')}",
        f"Approved: {syllabus.get('approved', '')}",
        f"Decision: {syllabus.get('decision', '')}",
        "",
        "## Description",
        syllabus.get("description") or "_No data captured yet._",
        "",
        "## Learning Outcomes",
        _table(syllabus.get("learning_outcomes", [])),
        "## Assessment",
        _table(syllabus.get("assessments", [])),
        "## Schedule",
        _table(syllabus.get("schedule", [])),
        "## Constructive Questions",
        _table(syllabus.get("constructive_questions", [])),
        "## Materials",
        _table(syllabus.get("materials", [])),
    ]
    frontmatter = _frontmatter(
        {
            "id": syllabus["id"],
            "type": "Syllabus",
            "syllabus_id": syllabus["syllabus_id"],
            "subject_code": syllabus.get("subject_code", ""),
            "credits": syllabus.get("credits"),
            "degree_level": syllabus.get("degree_level", ""),
            "prerequisite": syllabus.get("prerequisite", ""),
            "prerequisite_codes": prerequisite_codes,
            "active": syllabus.get("active"),
            "approved": syllabus.get("approved"),
            "source_path": syllabus.get("source_path", ""),
        }
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(frontmatter + "\n".join(body) + "\n", encoding="utf-8")
    return note_name


def export_obsidian(
    normalized_dir: Path | None = None,
    vault_dir: Path | None = None,
) -> None:
    source = normalized_dir or PROJECT_ROOT / "data/normalized/syllabi"
    vault = vault_dir or PROJECT_ROOT / "vault"
    for folder in ("Subjects", "Syllabi", "Curricula", "Materials", "Index"):
        (vault / folder).mkdir(parents=True, exist_ok=True)

    by_subject: dict[str, list[dict[str, Any]]] = {}
    prerequisite_by_subject: dict[str, list[str]] = {}
    required_by_subject: dict[str, list[str]] = {}
    syllabi = []
    for path in sorted(source.glob("*.json")):
        if not path.stem.isdigit():
            continue
        syllabus = json.loads(path.read_text(encoding="utf-8"))
        if _is_inactive(syllabus):
            print(
                f"exclude inactive syllabus {syllabus.get('syllabus_id')} "
                f"({syllabus.get('subject_code', '')}) from Obsidian"
            )
            continue
        syllabi.append(syllabus)

    subject_codes = {syllabus.get("subject_code", "") for syllabus in syllabi if syllabus.get("subject_code")}

    for syllabus in syllabi:
        subject_code = syllabus.get("subject_code", "")
        prerequisite_codes = extract_prerequisite_codes(syllabus.get("prerequisite", ""), subject_codes)
        if subject_code:
            prerequisite_by_subject.setdefault(subject_code, [])
            for prerequisite_code in prerequisite_codes:
                if prerequisite_code == subject_code:
                    continue
                if prerequisite_code not in prerequisite_by_subject[subject_code]:
                    prerequisite_by_subject[subject_code].append(prerequisite_code)
                required_by_subject.setdefault(prerequisite_code, [])
                if subject_code not in required_by_subject[prerequisite_code]:
                    required_by_subject[prerequisite_code].append(subject_code)
        _write_syllabus(vault, syllabus, prerequisite_codes)
        if syllabus.get("subject_code"):
            by_subject.setdefault(syllabus["subject_code"], []).append(syllabus)

    for subject_code, syllabi in sorted(by_subject.items()):
        path = vault / "Subjects" / f"{_safe_name(subject_code)}.md"
        first = syllabi[0]
        links = "\n".join(f"- [[SYL-{item['syllabus_id']}]]" for item in syllabi)
        content = _frontmatter(
            {
                "id": f"subject:{subject_code}",
                "type": "Subject",
                "code": subject_code,
                "name": first.get("subject_name", ""),
                "prerequisites": prerequisite_by_subject.get(subject_code, []),
                "required_by": required_by_subject.get(subject_code, []),
            }
        )
        content += f"# {subject_code}\n\n"
        content += f"{first.get('subject_name', '')}\n\n"
        content += "## Prerequisites\n\n"
        content += _links(prerequisite_by_subject.get(subject_code, [])) + "\n"
        content += "## Required By\n\n"
        content += _links(required_by_subject.get(subject_code, [])) + "\n"
        content += "## Syllabus Versions\n\n"
        content += links + "\n"
        path.write_text(content, encoding="utf-8")

    index = vault / "Index" / "Home.md"
    subject_links = "\n".join(f"- [[{code}]]" for code in sorted(by_subject))
    index.write_text(f"# FLM Knowledge Base\n\n## Subjects\n\n{subject_links}\n", encoding="utf-8")
