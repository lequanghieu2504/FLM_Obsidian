from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import sqlite3
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import requests
from bs4 import BeautifulSoup

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.auth.session import connect_cdp_context  # noqa: E402
from src.config import PROJECT_ROOT, settings  # noqa: E402
from src.crawler.subject_discovery import fetch_subject_codes  # noqa: E402
from src.crawler.syllabus_detail import (  # noqa: E402
    detect_heading,
    is_valid_syllabus_detail,
)
from src.crawler.syllabus_index import active_syllabus_items, parse_syllabus_table  # noqa: E402
from src.exporter.obsidian import export_obsidian  # noqa: E402
from src.graph.builder import build_graph  # noqa: E402
from src.indexer.sqlite_indexer import build_sqlite  # noqa: E402
from src.parser.syllabus_parser import (  # noqa: E402
    GENERAL_KEYS,
    _classify_table,
    _clean,
    _field_key,
    _parse_tabular_rows,
    _table_rows,
    parse_syllabus_html,
)


PREFIXES = [
    "PR",
    "PRO",
    "SW",
    "SWE",
    "SE",
    "DB",
    "ITE",
    "CSI",
    "AI",
    "MAD",
    "ECO",
    "MKT",
    "FIN",
    "ACC",
    "BUS",
    "LAW",
    "MAN",
    "ENG",
    "JPD",
    "CHN",
    "VNR",
    "HCM",
    "SSL",
    "SSG",
    "PHE",
    "MAE",
    "MAS",
    "CEA",
    "PMG",
    "IB",
    "OSG",
    "NWC",
]

SECTION_HEADERS = {
    "learning_outcomes": {"clo name", "clo details"},
    "assessments": {"category", "type", "part", "weight", "completion criteria"},
    "schedule": {"session", "topic", "learning-teaching type", "itu", "student materials"},
    "constructive_questions": {"session no", "name", "details"},
    "materials": {"material description", "author", "publisher", "isbn"},
}


@dataclass
class Issue:
    subject_code: str
    syllabus_id: int | None
    stage: str
    severity: str
    reason: str


@dataclass
class Metric:
    syllabus_id: int
    subject_code: str
    syllabus_name: str
    active: bool | None
    approved: bool | None
    credits: int | None
    clo_count: int
    assessment_count: int
    schedule_count: int
    material_count: int
    prerequisite_state: str
    status: str = "PASS"
    issues: list[Issue] = field(default_factory=list)


def info_value(info: dict[str, str], *keys: str) -> str:
    wanted = {_field_key(key) for key in keys}
    for key, value in info.items():
        if _field_key(key) in wanted:
            return value
    return ""


def raw_general_value(html: str, key: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    wanted = _field_key(key)
    for table in soup.select("table"):
        for row in _table_rows(table):
            if len(row) >= 2 and _field_key(row[0]) == wanted:
                return _clean(" ".join(row[1:]))
    return ""


def table_diagnostics(html: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    soup = BeautifulSoup(html, "html.parser")
    unknown: list[dict[str, Any]] = []
    classified: list[dict[str, Any]] = []
    for index, table in enumerate(soup.select("table")):
        rows = _table_rows(table)
        if not rows:
            continue
        section = _classify_table(rows)
        header = rows[0]
        normalized_header = [_clean(cell).rstrip(":").lower() for cell in header]
        entry = {
            "index": index,
            "section": section,
            "header": header,
            "row_count": max(0, len(rows) - 1),
        }
        if section is None:
            has_table_like_header = len(header) > 2 or any(cell in GENERAL_KEYS for cell in normalized_header)
            if has_table_like_header:
                unknown.append(entry)
        else:
            classified.append(entry)
    return unknown, classified


def raw_schedule_row_count(classified: list[dict[str, Any]]) -> int:
    return sum(item["row_count"] for item in classified if item["section"] == "schedule")


def has_general_table_but_unclassified(unknown: list[dict[str, Any]]) -> bool:
    for item in unknown:
        normalized = [_clean(cell).rstrip(":").lower() for cell in item["header"]]
        if any(cell in GENERAL_KEYS for cell in normalized):
            return True
    return False


def section_contamination(data: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    for section, records in (
        ("learning_outcomes", data.get("learning_outcomes") or []),
        ("assessments", data.get("assessments") or []),
        ("schedule", data.get("schedule") or []),
        ("materials", data.get("materials") or []),
    ):
        other_headers = set().union(*(headers for name, headers in SECTION_HEADERS.items() if name != section))
        for record in records:
            keys = {_clean(key).rstrip(":").lower() for key in record}
            overlap = keys & other_headers
            if overlap:
                reasons.append(f"{section} contains foreign columns: {', '.join(sorted(overlap))}")
                break
    return reasons


def validate_normalized(
    item: dict[str, Any],
    html: str,
    data: dict[str, Any] | None,
    parse_error: Exception | None,
) -> tuple[Metric | None, list[Issue], list[dict[str, Any]]]:
    subject_code = item.get("subject_code", "")
    syllabus_id = int(item["syllabus_id"])
    issues: list[Issue] = []
    unknown, classified = table_diagnostics(html)

    def fail(stage: str, reason: str) -> None:
        issues.append(Issue(subject_code, syllabus_id, stage, "FAIL", reason))

    def warn(stage: str, reason: str) -> None:
        issues.append(Issue(subject_code, syllabus_id, stage, "WARN", reason))

    if parse_error is not None:
        fail("normalize", f"parser threw exception: {parse_error}")
        return None, issues, unknown

    assert data is not None
    raw_name = raw_general_value(html, "Syllabus Name")
    raw_schedule_rows = raw_schedule_row_count(classified)
    general = data.get("general_information") or {}

    if not data.get("subject_code"):
        fail("validate", "subject_code missing")
    if raw_name and not data.get("syllabus_name"):
        fail("validate", "syllabus_name missing while raw HTML contains Syllabus Name")
    if has_general_table_but_unclassified(unknown):
        fail("validate", "general info table exists but parser cannot classify it")
    for item_unknown in unknown:
        fail("validate", f"table header signature is unknown: {item_unknown['header']}")
    for reason in section_contamination(data):
        fail("validate", reason)
    if raw_schedule_rows > 0 and not data.get("schedule"):
        fail("validate", f"{raw_schedule_rows} raw schedule rows exist but normalized schedule is empty")

    if not data.get("learning_outcomes"):
        warn("validate", "CLO count = 0")
    if not data.get("assessments"):
        warn("validate", "assessment count = 0")
    if not data.get("materials"):
        warn("validate", "materials count = 0")
    schedule = data.get("schedule") or []
    schedule_count = len(schedule)
    if raw_schedule_rows > 0:
        seen_session_numbers: set[int] = set()
        duplicate_session_numbers: set[int] = set()
        unparsable_sessions: list[str] = []
        for session in schedule:
            session_text = str(session.get("Session", "")).strip()
            try:
                session_number = int(session_text)
            except ValueError:
                unparsable_sessions.append(session_text)
                continue
            if session_number in seen_session_numbers:
                duplicate_session_numbers.add(session_number)
            seen_session_numbers.add(session_number)
        if unparsable_sessions:
            warn("validate", f"schedule session numbers do not parse: {unparsable_sessions[:5]}")
        if duplicate_session_numbers:
            warn("validate", f"unexpected duplicate schedule session numbers: {sorted(duplicate_session_numbers)}")
    for key in ("Syllabus ID", "Syllabus Name", "Subject Code", "NoCredit", "IsActive", "IsApproved"):
        if raw_general_value(html, key) == "":
            warn("validate", f"important general field empty in raw HTML: {key}")

    status = "FAIL" if any(issue.severity == "FAIL" for issue in issues) else ("WARN" if issues else "PASS")
    metric = Metric(
        syllabus_id=syllabus_id,
        subject_code=data.get("subject_code", ""),
        syllabus_name=data.get("syllabus_name", ""),
        active=data.get("active"),
        approved=data.get("approved"),
        credits=data.get("credits"),
        clo_count=len(data.get("learning_outcomes") or []),
        assessment_count=len(data.get("assessments") or []),
        schedule_count=schedule_count,
        material_count=len(data.get("materials") or []),
        prerequisite_state="non-empty" if data.get("prerequisite") else "empty",
        status=status,
        issues=issues,
    )
    return metric, issues, unknown


def discover_subject_codes(limit: int) -> list[str]:
    session = requests.Session()
    candidates: list[str] = []
    seen: set[str] = set()
    for prefix in PREFIXES:
        try:
            codes = fetch_subject_codes(session, prefix)
        except Exception:
            continue
        for code in codes:
            if code not in seen:
                candidates.append(code)
                seen.add(code)
    buckets: dict[str, list[str]] = defaultdict(list)
    for code in candidates:
        match = re.match(r"[A-Z]+", code)
        buckets[match.group(0) if match else code[:1]].append(code)
    selected: list[str] = []
    while len(selected) < max(limit * 3, limit) and buckets:
        for key in sorted(list(buckets)):
            if buckets[key]:
                selected.append(buckets[key].pop(0))
                if len(selected) >= max(limit * 3, limit):
                    break
            if not buckets.get(key):
                buckets.pop(key, None)
    return selected or PREFIXES[: max(limit * 2, limit)]


def page_content(page, url: str) -> tuple[str, str, str]:
    page.goto(url, wait_until="networkidle", timeout=settings.timeout_seconds * 1000)
    return page.content(), page.url, page.title()


def resolve_syllabi_via_cdp(
    page,
    subject_codes: list[str],
    limit: int,
) -> tuple[list[dict[str, Any]], list[Issue], dict[str, int]]:
    candidates: dict[int, Any] = {}
    issues: list[Issue] = []
    stats = {
        "subjects_discovered": len(subject_codes),
        "syllabus_rows_found": 0,
        "active_syllabi_selected": 0,
        "inactive_syllabi_skipped": 0,
        "subjects_without_active_syllabus": 0,
        "detail_pages_fetched": 0,
    }
    for code in subject_codes:
        query = urlencode({"searchOn": "Code", "keyword": code})
        url = f"{settings.base_url}/gui/role/student/SyllabusManagement?{query}"
        try:
            html, final_url, _title = page_content(page, url)
            rows = parse_syllabus_table(html)
            matching = [row for row in rows if row.subject_code.upper().startswith(code.upper())] or rows
            if not matching:
                issues.append(Issue(code, None, "resolve", "WARN", "no syllabus rows found"))
                continue
            active_rows = active_syllabus_items(matching)
            stats["syllabus_rows_found"] += len(matching)
            stats["inactive_syllabi_skipped"] += sum(1 for row in matching if row.is_active is not True)
            if not active_rows:
                stats["subjects_without_active_syllabus"] += 1
                print(f"{code}: skipped_no_active_syllabus")
            for row in matching:
                if row.is_active is not True:
                    print(f"{code}: skip inactive syllabus {row.syllabus_id} before detail fetch")
            for row in active_rows:
                candidates[row.syllabus_id] = row
        except Exception as exc:  # noqa: BLE001 - batch must continue.
            issues.append(Issue(code, None, "resolve", "FAIL", f"{type(exc).__name__}: {exc}"))

    buckets: dict[str, list[Any]] = defaultdict(list)
    for row in candidates.values():
        match = re.match(r"[A-Z]+", row.subject_code.upper())
        buckets[match.group(0) if match else row.subject_code[:1].upper()].append(row)
    for rows in buckets.values():
        rows.sort(key=lambda row: row.syllabus_id, reverse=True)

    selected_rows: list[Any] = []
    while len(selected_rows) < limit and buckets:
        for key in sorted(list(buckets)):
            rows = buckets.get(key) or []
            if rows:
                selected_rows.append(rows.pop(0))
                if len(selected_rows) >= limit:
                    break
            if not rows:
                buckets.pop(key, None)
    selected = [row.to_dict() for row in selected_rows]
    stats["active_syllabi_selected"] = len(selected)
    return selected, issues, stats


def fetch_detail_via_cdp(
    page,
    syllabus_id: int,
    raw_dir: Path,
    attempts: int = 3,
) -> tuple[str | None, dict[str, Any] | None, Exception | None]:
    url = f"{settings.base_url}/gui/role/student/SyllabusDetails?sylID={syllabus_id}"
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            html, final_url, title = page_content(page, url)
            if not is_valid_syllabus_detail(html, final_url):
                raise RuntimeError(f"loaded page is not a valid syllabus detail page: {final_url}")
            raw_dir.mkdir(parents=True, exist_ok=True)
            target = raw_dir / f"{syllabus_id}.html"
            target.write_text(html, encoding="utf-8")
            return html, {
                "final_url": final_url,
                "title": title,
                "heading": detect_heading(html),
                "html_bytes": len(html.encode("utf-8")),
                "raw_path": str(target),
            }, None
        except Exception as exc:  # noqa: BLE001 - batch must continue.
            last_error = exc
            print(f"retry detail fetch {syllabus_id}: attempt {attempt}/{attempts} failed: {exc}")
    return None, None, last_error


def issue_to_dict(issue: Issue) -> dict[str, Any]:
    return asdict(issue)


def metric_to_dict(metric: Metric) -> dict[str, Any]:
    data = asdict(metric)
    data["issues"] = [issue_to_dict(issue) for issue in metric.issues]
    return data


def source_path_for(path: Path) -> str:
    try:
        return str(path.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(path)


def validate_sqlite(db_path: Path, normalized_dir: Path) -> dict[str, Any]:
    normalized = [json.loads(path.read_text(encoding="utf-8")) for path in sorted(normalized_dir.glob("*.json"))]
    total_sessions = sum(len(item.get("schedule") or []) for item in normalized)
    with sqlite3.connect(db_path) as connection:
        connection.row_factory = sqlite3.Row
        syllabus_count = connection.execute("SELECT COUNT(*) FROM syllabi").fetchone()[0]
        chunk_count = connection.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        schedule_chunk_count = connection.execute("SELECT COUNT(*) FROM chunks WHERE section = 'schedule'").fetchone()[0]
        schedule_chunks_by_syllabus = {
            int(row["syllabus_id"]): int(row["count"])
            for row in connection.execute(
                "SELECT syllabus_id, COUNT(*) AS count FROM chunks WHERE section = 'schedule' GROUP BY syllabus_id"
            )
        }
        chunked_ids = {
            int(row[0])
            for row in connection.execute("SELECT DISTINCT syllabus_id FROM chunks WHERE syllabus_id IS NOT NULL")
        }
    normalized_ids = {int(item["syllabus_id"]) for item in normalized}
    schedule_count_mismatches = [
        {
            "syllabus_id": int(item["syllabus_id"]),
            "normalized_schedule_count": len(item.get("schedule") or []),
            "sqlite_schedule_chunk_count": schedule_chunks_by_syllabus.get(int(item["syllabus_id"]), 0),
        }
        for item in normalized
        if len(item.get("schedule") or []) != schedule_chunks_by_syllabus.get(int(item["syllabus_id"]), 0)
    ]
    return {
        "total_syllabus_count": syllabus_count,
        "total_chunk_count": chunk_count,
        "total_schedule_chunks": schedule_chunk_count,
        "total_normalized_session_count": total_sessions,
        "schedule_chunks_equal_sessions": schedule_chunk_count == total_sessions,
        "every_normalized_syllabus_has_chunks": normalized_ids <= chunked_ids,
        "missing_chunk_syllabus_ids": sorted(normalized_ids - chunked_ids),
        "schedule_count_mismatches": schedule_count_mismatches,
    }


def run_retrieval_tests(db_path: Path, metrics: list[Metric]) -> list[dict[str, Any]]:
    def detect_section(question: str) -> str | None:
        lower = question.lower()
        if "prerequisite" in lower or "pre-requisite" in lower:
            return "prerequisite"
        if "tín chỉ" in lower or "tin chi" in lower or "credit" in lower:
            return "general_information"
        if any(term in lower for term in ("assessment", "final", "thi", "cuối kỳ", "cuoi ky", "grade", "%")):
            return "assessment"
        if "schedule" in lower or "session" in lower or "hiragana" in lower or "buổi" in lower:
            return "schedule"
        return None

    def detect_session_number(question: str) -> int | None:
        match = re.search(r"\bsession\s+(\d+)\b", question, re.IGNORECASE)
        return int(match.group(1)) if match else None

    def search_text(question: str, subject_code: str | None, section: str | None, session_number: int | None) -> str:
        if session_number is not None:
            return ""
        if section == "schedule" and "hiragana" in question.lower():
            return "hiragana"
        if subject_code is not None and section is not None and section != "schedule":
            return ""
        text = question
        if subject_code:
            text = re.sub(re.escape(subject_code), "", text, flags=re.IGNORECASE)
        if section:
            text = re.sub(re.escape(section.replace("_", " ")), "", text, flags=re.IGNORECASE)
        return text.strip()

    rng = random.Random(393)
    pool = metrics[:]
    rng.shuffle(pool)
    sample = pool[: min(10, len(pool))]
    tests: list[dict[str, Any]] = []
    with sqlite3.connect(db_path) as connection:
        connection.row_factory = sqlite3.Row
        for metric in sample:
            code = metric.subject_code
            queries = [
                f"{code} assessment",
                f"{code} prerequisite",
                f"{code} session 1",
                f"{code} học bao nhiêu tín chỉ",
            ]
            for query in queries:
                code_match = re.search(r"\b[A-Z]{2,8}\d{3}[A-Za-z]?\b", query, re.IGNORECASE)
                subject_code = code_match.group(0).upper() if code_match else None
                section = detect_section(query)
                session_number = detect_session_number(query)
                text = search_text(query, subject_code, section, session_number)
                where: list[str] = []
                args: list[Any] = []
                if subject_code is not None:
                    where.append("subject_code_norm = ?")
                    args.append(subject_code)
                if section is not None:
                    where.append("section = ?")
                    args.append(section)
                if session_number is not None:
                    where.append("session_number = ?")
                    args.append(session_number)
                for term in [term for term in re.split(r"\s+", text.strip()) if len(term) > 1]:
                    if re.match(r"^[A-Z]{2,8}\d{3}[A-Za-z]?$", term, re.IGNORECASE):
                        continue
                    where.append("content LIKE ?")
                    args.append(f"%{term}%")
                sql = "SELECT subject_code, syllabus_id, section, session_number, title FROM chunks"
                if where:
                    sql += " WHERE " + " AND ".join(where)
                sql += " ORDER BY subject_code, section, session_number LIMIT 5"
                rows = connection.execute(sql, args).fetchall()
                tests.append(
                    {
                        "query": query,
                        "subject_code_filter": subject_code,
                        "section_filter": section,
                        "session_filter": session_number,
                        "result_count": len(rows),
                        "top_results": [dict(row) for row in rows],
                    }
                )
    return tests


def write_markdown_report(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# Controlled Batch Validation Report",
        "",
        f"Total attempted: {report['summary']['total_attempted']}",
        f"Successfully fetched: {report['summary']['successfully_fetched']}",
        f"Successfully normalized: {report['summary']['successfully_normalized']}",
        f"PASS: {report['summary']['pass']}",
        f"WARN: {report['summary']['warn']}",
        f"FAIL: {report['summary']['fail']}",
        "",
        "## Warnings and Failures",
        "",
    ]
    if report["issues"]:
        for issue in report["issues"]:
            lines.append(
                f"- {issue['severity']} {issue['subject_code'] or '(unknown)'} "
                f"SYL-{issue['syllabus_id'] or '?'} [{issue['stage']}]: {issue['reason']}"
            )
    else:
        lines.append("- None")
    lines.extend(["", "## Unseen Table Structures", ""])
    if report["unseen_table_structures"]:
        for item in report["unseen_table_structures"]:
            lines.append(f"- SYL-{item['syllabus_id']} table {item['index']}: {item['header']}")
    else:
        lines.append("- None")
    lines.extend(["", "## SQLite", "", "```json", json.dumps(report["sqlite"], indent=2, ensure_ascii=False), "```"])
    lines.extend(["", "## Crawl Stats", "", "```json", json.dumps(report["crawl_stats"], indent=2, ensure_ascii=False), "```"])
    lines.extend(["", "## Retrieval Samples", ""])
    for item in report["retrieval_tests"]:
        lines.append(f"- `{item['query']}` -> {item.get('result_count', 0)} results")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=30)
    parser.add_argument("--cdp-url", default="http://localhost:9222")
    parser.add_argument("--output-dir", type=Path, default=PROJECT_ROOT / "data/batch_validation")
    args = parser.parse_args()

    base = args.output_dir
    if base.exists():
        shutil.rmtree(base)
    raw_dir = base / "raw/syllabi"
    normalized_dir = base / "normalized/syllabi"
    index_dir = base / "index"
    graph_dir = base / "graph"
    vault_dir = base / "vault"
    db_path = base / "knowledge.db"
    for directory in (raw_dir, normalized_dir, index_dir, graph_dir, vault_dir):
        directory.mkdir(parents=True, exist_ok=True)

    subjects = discover_subject_codes(args.limit)
    playwright, browser, context = connect_cdp_context(args.cdp_url)
    page = context.pages[0] if context.pages else context.new_page()
    all_issues: list[Issue] = []
    unknown_tables: list[dict[str, Any]] = []
    fetch_results: list[dict[str, Any]] = []
    metrics: list[Metric] = []
    normalized_rows: list[dict[str, Any]] = []
    try:
        syllabi, resolve_issues, crawl_stats = resolve_syllabi_via_cdp(page, subjects, args.limit)
        all_issues.extend(resolve_issues)
        (index_dir / "subjects.json").write_text(json.dumps(subjects, indent=2, ensure_ascii=False), encoding="utf-8")
        (index_dir / "syllabi.json").write_text(json.dumps(syllabi, indent=2, ensure_ascii=False), encoding="utf-8")

        for item in syllabi:
            syllabus_id = int(item["syllabus_id"])
            if item.get("is_active") is not True:
                print(f"{item.get('subject_code', '')}: skip inactive syllabus {syllabus_id} before detail fetch")
                continue
            html, fetch_info, fetch_error = fetch_detail_via_cdp(page, syllabus_id, raw_dir)
            if fetch_error is not None:
                all_issues.append(
                    Issue(item.get("subject_code", ""), syllabus_id, "fetch", "FAIL", f"{type(fetch_error).__name__}: {fetch_error}")
                )
                continue
            assert html is not None
            fetch_results.append(fetch_info or {})
            crawl_stats["detail_pages_fetched"] += 1
            data = None
            parse_error = None
            try:
                parsed = parse_syllabus_html(
                    html,
                    syllabus_id=syllabus_id,
                    source_path=source_path_for(raw_dir / f"{syllabus_id}.html"),
                    index_metadata=item,
                )
                data = parsed.to_dict()
                if data.get("active") is False:
                    all_issues.append(
                        Issue(
                            data.get("subject_code", item.get("subject_code", "")),
                            syllabus_id,
                            "normalize",
                            "WARN",
                            "defensive exclusion: parsed active=false after detail fetch",
                        )
                    )
                    print(
                        f"{data.get('subject_code', item.get('subject_code', ''))}: "
                        f"exclude inactive syllabus {syllabus_id} after detail parsing"
                    )
                    continue
                (normalized_dir / f"{syllabus_id}.json").write_text(
                    json.dumps(data, indent=2, ensure_ascii=False),
                    encoding="utf-8",
                )
                normalized_rows.append(data)
            except Exception as exc:  # noqa: BLE001 - validation captures parser failures.
                parse_error = exc
            metric, issues, unknown = validate_normalized(item, html, data, parse_error)
            all_issues.extend(issues)
            for unknown_item in unknown:
                unknown_tables.append({"syllabus_id": syllabus_id, **unknown_item})
            if metric is not None:
                metrics.append(metric)
    finally:
        browser.close()
        playwright.stop()

    build_graph(normalized_dir=normalized_dir, graph_dir=graph_dir)
    export_obsidian(normalized_dir=normalized_dir, vault_dir=vault_dir)
    build_sqlite(normalized_dir=normalized_dir, db_path=db_path)

    sqlite_report = validate_sqlite(db_path, normalized_dir)
    if not sqlite_report["schedule_chunks_equal_sessions"]:
        all_issues.append(Issue("", None, "sqlite", "FAIL", "schedule chunk count does not equal normalized session count"))
    if not sqlite_report["every_normalized_syllabus_has_chunks"]:
        all_issues.append(Issue("", None, "sqlite", "FAIL", "some normalized syllabi have no corresponding chunks"))
    if sqlite_report["schedule_count_mismatches"]:
        all_issues.append(Issue("", None, "sqlite", "FAIL", "normalized schedule counts do not match SQLite schedule chunks"))
    retrieval_tests = run_retrieval_tests(db_path, metrics)

    status_counts = Counter(metric.status for metric in metrics)
    fetch_failures = sum(1 for issue in all_issues if issue.stage == "fetch" and issue.severity == "FAIL")
    report = {
        "summary": {
            "total_attempted": len(json.loads((index_dir / "syllabi.json").read_text(encoding="utf-8"))),
            "successfully_fetched": len(fetch_results),
            "successfully_normalized": len(metrics),
            "pass": status_counts["PASS"],
            "warn": status_counts["WARN"],
            "fail": status_counts["FAIL"] + fetch_failures,
        },
        "metrics": [metric_to_dict(metric) for metric in metrics],
        "issues": [issue_to_dict(issue) for issue in all_issues],
        "unseen_table_structures": unknown_tables,
        "sqlite": sqlite_report,
        "retrieval_tests": retrieval_tests,
        "crawl_stats": crawl_stats,
        "outputs": {
            "raw_dir": str(raw_dir),
            "normalized_dir": str(normalized_dir),
            "graph_dir": str(graph_dir),
            "vault_dir": str(vault_dir),
            "db_path": str(db_path),
        },
    }
    (base / "batch_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    write_markdown_report(report, base / "batch_report.md")
    print(json.dumps(report["summary"], indent=2, ensure_ascii=False))
    print(base / "batch_report.md")


if __name__ == "__main__":
    main()
