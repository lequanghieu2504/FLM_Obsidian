from __future__ import annotations

import json
import string
from pathlib import Path

import requests

from src.config import PROJECT_ROOT, settings
from src.crawler.http import polite_pause, retry


ALPHABET = string.ascii_uppercase + string.digits + "_-"


def fetch_subject_codes(session: requests.Session, prefix: str) -> list[str]:
    response = retry(
        lambda: session.get(
            f"{settings.base_url}/api/ListSubjectCodeHandler.ashx",
            params={"term": prefix},
            timeout=settings.timeout_seconds,
        )
    )
    response.raise_for_status()
    data = response.json()
    if not isinstance(data, list):
        raise ValueError(f"Expected subject array for prefix {prefix!r}")
    polite_pause()
    return [str(item).strip().upper() for item in data if str(item).strip()]


def discover_subjects(
    session: requests.Session,
    output_path: Path | None = None,
    suspected_cap: int = 30,
    max_depth: int = 6,
) -> list[str]:
    output = output_path or PROJECT_ROOT / "data/index/subjects.json"
    seen_prefixes: set[str] = set()
    subjects: set[str] = set()

    def visit(prefix: str) -> None:
        if prefix in seen_prefixes or len(prefix) > max_depth:
            return
        seen_prefixes.add(prefix)
        codes = fetch_subject_codes(session, prefix)
        subjects.update(codes)
        if len(codes) >= suspected_cap:
            for char in ALPHABET:
                visit(prefix + char)

    for char in string.ascii_uppercase:
        visit(char)

    output.parent.mkdir(parents=True, exist_ok=True)
    result = sorted(subjects)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return result

