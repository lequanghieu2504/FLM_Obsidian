from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

from src.config import PROJECT_ROOT, settings
from src.crawler.http import polite_pause, retry
from src.models.syllabus import SyllabusIndexItem


def _stats_path(output_path: Path) -> Path:
    return output_path.with_name("crawl_stats.json")


def _load_stats(path: Path) -> dict[str, int]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _write_stats(path: Path, updates: dict[str, int]) -> dict[str, int]:
    stats = _load_stats(path)
    stats.update(updates)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf-8")
    return stats


def _bool(text: str) -> bool | None:
    cleaned = text.strip().lower()
    if cleaned in {"true", "yes", "1", "active", "approved"}:
        return True
    if cleaned in {"false", "no", "0", "inactive", "not approved"}:
        return False
    return None


def _cell_bool(cell) -> bool | None:
    checkbox = cell.select_one("input[type='checkbox']")
    if checkbox is not None:
        return checkbox.has_attr("checked")
    return _bool(cell.get_text(" ", strip=True))


def parse_syllabus_table(html: str) -> list[SyllabusIndexItem]:
    soup = BeautifulSoup(html, "html.parser")
    table = soup.select_one("#gvSyllabus")
    if table is None:
        page_text = soup.get_text(" ", strip=True)
        has_management_heading = any(
            heading.get_text(" ", strip=True) == "Syllabus Management"
            for heading in soup.find_all(["h1", "h2", "h3"])
        )
        has_search_form = soup.select_one("form[action*='SyllabusManagement'] input[name='keyword']") is not None
        if has_management_heading and has_search_form and "Syllabus ID" not in page_text:
            return []
        raise ValueError("Could not find #gvSyllabus in syllabus search response")

    rows = table.select("tr")
    items: list[SyllabusIndexItem] = []
    for row in rows[1:]:
        cells = [cell.get_text(" ", strip=True) for cell in row.select("td")]
        if len(cells) < 7:
            continue
        link = row.select_one("a[href*='SyllabusDetails']")
        href = link.get("href", "") if link else ""
        syllabus_id_match = re.search(r"sylID=(\d+)", href) or re.search(r"\d+", cells[0])
        if not syllabus_id_match:
            continue
        syllabus_id = int(syllabus_id_match.group(1 if "sylID" in syllabus_id_match.group(0) else 0))
        detail_url = urljoin(settings.base_url, href) if href else f"{settings.base_url}/gui/role/student/SyllabusDetails?sylID={syllabus_id}"
        items.append(
            SyllabusIndexItem(
                syllabus_id=syllabus_id,
                subject_code=cells[1].upper(),
                subject_name=cells[2],
                syllabus_name=cells[3],
                is_active=_cell_bool(row.select("td")[4]),
                is_approved=_cell_bool(row.select("td")[5]),
                decision=cells[6],
                detail_url=detail_url,
            )
        )
    return items


def active_syllabus_items(items: list[SyllabusIndexItem]) -> list[SyllabusIndexItem]:
    return [item for item in items if item.is_active is True]


def discover_syllabi(
    session: requests.Session,
    subjects_path: Path | None = None,
    output_path: Path | None = None,
) -> list[dict]:
    subjects_file = subjects_path or PROJECT_ROOT / "data/index/subjects.json"
    output = output_path or PROJECT_ROOT / "data/index/syllabi.json"
    subjects = json.loads(subjects_file.read_text(encoding="utf-8"))
    all_items: dict[int, SyllabusIndexItem] = {}
    stats = {
        "subjects_discovered": len(subjects),
        "syllabus_rows_found": 0,
        "active_syllabi_selected": 0,
        "inactive_syllabi_skipped": 0,
        "subjects_without_active_syllabus": 0,
        "detail_pages_fetched": 0,
    }

    for subject_code in subjects:
        response = retry(
            lambda code=subject_code: session.get(
                f"{settings.base_url}/gui/role/student/SyllabusManagement",
                params={"searchOn": "Code", "keyword": code},
                timeout=settings.timeout_seconds,
            )
        )
        response.raise_for_status()
        rows = parse_syllabus_table(response.text)
        active_rows = active_syllabus_items(rows)
        stats["syllabus_rows_found"] += len(rows)
        stats["inactive_syllabi_skipped"] += sum(1 for item in rows if item.is_active is not True)
        stats["active_syllabi_selected"] += len(active_rows)
        if not active_rows:
            stats["subjects_without_active_syllabus"] += 1
            print(f"{subject_code}: skipped_no_active_syllabus")
        for item in rows:
            if item.is_active is not True:
                print(f"{subject_code}: skip inactive syllabus {item.syllabus_id} before detail fetch")
        for item in active_rows:
            all_items[item.syllabus_id] = item
        polite_pause()

    rows = [item.to_dict() for item in sorted(all_items.values(), key=lambda item: item.syllabus_id)]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")
    stats["active_syllabi_selected"] = len(rows)
    _write_stats(_stats_path(output), stats)
    print(f"crawl_stats: {json.dumps(stats, ensure_ascii=False)}")
    return rows


__all__ = [
    "active_syllabus_items",
    "discover_syllabi",
    "parse_syllabus_table",
]
