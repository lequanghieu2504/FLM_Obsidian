from __future__ import annotations

import argparse
import json
import re
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

from bs4 import BeautifulSoup, Tag

import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.auth.session import connect_cdp_context, looks_like_cloudflare_challenge, looks_like_login_page  # noqa: E402
from src.config import PROJECT_ROOT, settings  # noqa: E402
from src.crawler.syllabus_detail import detect_heading, is_valid_syllabus_detail  # noqa: E402
from src.crawler.syllabus_index import active_syllabus_items, parse_syllabus_table  # noqa: E402
from src.exporter.obsidian import export_obsidian  # noqa: E402
from src.graph.builder import build_graph  # noqa: E402
from src.indexer.sqlite_indexer import build_sqlite  # noqa: E402
from src.parser.syllabus_parser import _classify_table, _clean, _table_rows, parse_syllabus_html  # noqa: E402


PREFIX_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.*"
ROOT_PREFIXES = list(PREFIX_CHARS)
AUTOCOMPLETE_CAP = 30
DEFAULT_DELAY_SECONDS = 3.0


class BlockingDetected(RuntimeError):
    pass


@dataclass
class Failure:
    syllabus_id: int | None
    subject_code: str
    stage: str
    url: str
    error: str


def read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp_path.replace(path)


def load_state(path: Path) -> dict[str, Any]:
    state = read_json(path, {})
    state.setdefault("prefix_queries", {})
    state.setdefault("discovered_subjects", [])
    state.setdefault("subject_results", {})
    state.setdefault("active_syllabi", {})
    state.setdefault("detail_results", {})
    state.setdefault("failures", [])
    state.setdefault("blocked_events", [])
    return state


def save_state(path: Path, state: dict[str, Any]) -> None:
    state["stats"] = crawl_stats(state)
    write_json(path, state)


def clear_stale_blocked_at(state: dict[str, Any]) -> None:
    blocked_at = state.get("blocked_at")
    if not blocked_at:
        return
    syllabus_id = blocked_at.get("syllabus_id")
    if syllabus_id is None:
        return
    detail = state.get("detail_results", {}).get(str(syllabus_id), {})
    if detail.get("status") in {"existing_valid", "fetched"}:
        state.pop("blocked_at", None)


def crawl_stats(state: dict[str, Any]) -> dict[str, int]:
    subject_results = state.get("subject_results", {})
    detail_results = state.get("detail_results", {})
    return {
        "discovered_subjects": len(state.get("discovered_subjects", [])),
        "syllabus_rows_found": sum(int(item.get("rows_found", 0)) for item in subject_results.values()),
        "active_syllabi_selected": sum(len(item.get("active_syllabus_ids", [])) for item in subject_results.values()),
        "inactive_syllabi_skipped": sum(len(item.get("inactive_syllabus_ids", [])) for item in subject_results.values()),
        "unique_active_syllabus_ids": len(state.get("active_syllabi", {})),
        "detail_pages_existing_valid": sum(1 for item in detail_results.values() if item.get("status") == "existing_valid"),
        "detail_pages_fetched": sum(1 for item in detail_results.values() if item.get("status") == "fetched"),
        "detail_pages_failed": sum(1 for item in detail_results.values() if item.get("status") == "failed"),
        "subjects_without_syllabus_rows": sum(1 for item in subject_results.values() if item.get("status") == "no_rows"),
    }


def evaluate_autocomplete(page, prefix: str) -> list[str]:
    result = page.evaluate(
        """async ({base, prefix}) => {
          const response = await fetch(`${base}/api/ListSubjectCodeHandler.ashx?term=${encodeURIComponent(prefix)}`, {
            credentials: 'include'
          });
          const text = await response.text();
          return {status: response.status, url: response.url, text};
        }""",
        {"base": settings.base_url, "prefix": prefix},
    )
    if result["status"] != 200:
        raise RuntimeError(f"autocomplete HTTP {result['status']} at {result['url']}")
    try:
        data = json.loads(result["text"])
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"autocomplete returned non-JSON for prefix {prefix!r}") from exc
    if not isinstance(data, list):
        raise RuntimeError(f"autocomplete returned {type(data).__name__} for prefix {prefix!r}")
    return sorted({str(item).strip().upper() for item in data if str(item).strip()})


def discover_subjects(page, state_path: Path, state: dict[str, Any], max_depth: int, delay: float) -> list[str]:
    queue = list(ROOT_PREFIXES)
    for prefix, result in sorted(state["prefix_queries"].items()):
        if result.get("status") == "ok" and int(result.get("count", 0)) >= AUTOCOMPLETE_CAP and len(prefix) < max_depth:
            queue.extend(prefix + char for char in PREFIX_CHARS)
    seen = set(state["prefix_queries"])
    discovered = set(state.get("discovered_subjects", []))

    while queue:
        prefix = queue.pop(0)
        if prefix in seen or len(prefix) > max_depth:
            continue
        try:
            codes = evaluate_autocomplete(page, prefix)
            state["prefix_queries"][prefix] = {"status": "ok", "count": len(codes), "codes": codes}
            discovered.update(codes)
            if len(codes) >= AUTOCOMPLETE_CAP and len(prefix) < max_depth:
                queue.extend(prefix + char for char in PREFIX_CHARS)
        except Exception as exc:  # noqa: BLE001 - prefix failures are recorded and discovery continues.
            state["prefix_queries"][prefix] = {"status": "failed", "error": str(exc)}
        state["discovered_subjects"] = sorted(discovered)
        save_state(state_path, state)
        time.sleep(delay)
        seen.add(prefix)

    return state["discovered_subjects"]


def page_content(page, url: str) -> tuple[str, str, str]:
    page.goto(url, wait_until="networkidle", timeout=settings.timeout_seconds * 1000)
    return page.content(), page.url, page.title()


def response_kind(html: str, final_url: str, title: str) -> str:
    text = " ".join(BeautifulSoup(html, "html.parser").get_text(" ", strip=True).split()).lower()
    if looks_like_login_page(html, final_url):
        return "login"
    if looks_like_cloudflare_challenge(html, title):
        return "cloudflare"
    if is_valid_syllabus_detail(html, final_url):
        return "normal"
    if any(token in text for token in ("too many requests", "rate limit", "access denied", "temporarily blocked", "blocked")):
        return "blocked"
    if "errorpage" in final_url.lower() or "aspxerrorpath" in final_url.lower():
        return "error_page"
    return "normal"


def record_block_and_stop(
    state_path: Path,
    state: dict[str, Any],
    *,
    stage: str,
    subject_code: str,
    syllabus_id: int | None,
    url: str,
    final_url: str,
    title: str,
    reason: str,
) -> None:
    event = {
        "stage": stage,
        "subject_code": subject_code,
        "syllabus_id": syllabus_id,
        "url": url,
        "final_url": final_url,
        "title": title,
        "reason": reason,
        "resume_hint": f"{stage}:{subject_code or syllabus_id}",
    }
    state["blocked_events"].append(event)
    state["blocked_at"] = event
    save_state(state_path, state)
    raise BlockingDetected(
        f"blocking/rate-limit detected at {stage} subject={subject_code} syllabus_id={syllabus_id}: {reason}. "
        f"Resume later from {event['resume_hint']}."
    )


def resolve_syllabi(page, state_path: Path, state: dict[str, Any], delay: float) -> None:
    active_syllabi = state.setdefault("active_syllabi", {})
    subject_results = state.setdefault("subject_results", {})
    subjects = state.get("discovered_subjects", [])

    for index, subject_code in enumerate(subjects, start=1):
        existing = subject_results.get(subject_code)
        if existing and existing.get("status") != "failed":
            continue
        query = urlencode({"searchOn": "Code", "keyword": subject_code})
        url = f"{settings.base_url}/gui/role/student/SyllabusManagement?{query}"
        try:
            html, final_url, title = page_content(page, url)
            kind = response_kind(html, final_url, title)
            if kind in {"login", "cloudflare", "blocked"}:
                record_block_and_stop(
                    state_path,
                    state,
                    stage="resolve",
                    subject_code=subject_code,
                    syllabus_id=None,
                    url=url,
                    final_url=final_url,
                    title=title,
                    reason=kind,
                )
            rows = parse_syllabus_table(html)
            active_rows = active_syllabus_items(rows)
            inactive_rows = [row for row in rows if row.is_active is not True]
            if not rows:
                subject_results[subject_code] = {
                    "status": "no_rows",
                    "url": url,
                    "final_url": final_url,
                    "title": title,
                    "rows_found": 0,
                    "active_syllabus_ids": [],
                    "inactive_syllabus_ids": [],
                }
            else:
                subject_results[subject_code] = {
                    "status": "ok",
                    "url": url,
                    "final_url": final_url,
                    "title": title,
                    "rows_found": len(rows),
                    "active_syllabus_ids": [row.syllabus_id for row in active_rows],
                    "inactive_syllabus_ids": [row.syllabus_id for row in inactive_rows],
                }
            for row in inactive_rows:
                print(f"{subject_code}: skip inactive syllabus {row.syllabus_id} before detail fetch")
            for row in active_rows:
                active_syllabi[str(row.syllabus_id)] = row.to_dict()
        except BlockingDetected:
            raise
        except Exception as exc:  # noqa: BLE001 - subject failures are recorded and resolution continues.
            subject_results[subject_code] = {
                "status": "failed",
                "url": url,
                "rows_found": 0,
                "active_syllabus_ids": [],
                "inactive_syllabus_ids": [],
                "error": str(exc),
            }
            failure = asdict(Failure(None, subject_code, "resolve", url, str(exc)))
            if failure not in state["failures"]:
                state["failures"].append(failure)
        if index % 25 == 0:
            print(f"resolved {index}/{len(subjects)} subjects")
        save_state(state_path, state)
        time.sleep(delay)


def detail_url(syllabus_id: int) -> str:
    return f"{settings.base_url}/gui/role/student/SyllabusDetails?sylID={syllabus_id}"


def valid_existing_raw(path: Path, syllabus_id: int) -> bool:
    if not path.exists():
        return False
    html = path.read_text(encoding="utf-8", errors="replace")
    return is_valid_syllabus_detail(html, detail_url(syllabus_id))


def fetch_detail(page, syllabus_id: int, raw_dir: Path, retries: int) -> dict[str, Any]:
    url = detail_url(syllabus_id)
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            html, final_url, title = page_content(page, url)
            kind = response_kind(html, final_url, title)
            if kind in {"login", "cloudflare", "blocked"}:
                raise BlockingDetected(kind)
            if kind == "error_page":
                raise RuntimeError(f"loaded FLM error page: {final_url}")
            if not is_valid_syllabus_detail(html, final_url):
                raise RuntimeError(f"loaded page is not a valid syllabus detail page: {final_url}")
            raw_dir.mkdir(parents=True, exist_ok=True)
            target = raw_dir / f"{syllabus_id}.html"
            target.write_text(html, encoding="utf-8")
            return {
                "status": "fetched",
                "url": url,
                "final_url": final_url,
                "title": title,
                "heading": detect_heading(html),
                "html_bytes": len(html.encode("utf-8")),
                "raw_path": str(target),
            }
        except BlockingDetected:
            raise
        except Exception as exc:  # noqa: BLE001 - small retry window for transient browser/page failures.
            last_error = exc
            print(f"retry detail fetch {syllabus_id}: attempt {attempt}/{retries} failed: {exc}")
            time.sleep(0.5 * attempt)
    raise RuntimeError(str(last_error))


def crawl_details(page, state_path: Path, state: dict[str, Any], raw_dir: Path, retries: int, delay: float) -> None:
    detail_results = state.setdefault("detail_results", {})
    active_items = sorted(
        state.get("active_syllabi", {}).values(),
        key=lambda item: int(item["syllabus_id"]),
    )
    for index, item in enumerate(active_items, start=1):
        syllabus_id = int(item["syllabus_id"])
        key = str(syllabus_id)
        if detail_results.get(key, {}).get("status") in {"existing_valid", "fetched"}:
            continue
        target = raw_dir / f"{syllabus_id}.html"
        url = detail_url(syllabus_id)
        if valid_existing_raw(target, syllabus_id):
            detail_results[key] = {
                "status": "existing_valid",
                "syllabus_id": syllabus_id,
                "subject_code": item.get("subject_code", ""),
                "url": url,
                "raw_path": str(target),
            }
            save_state(state_path, state)
            continue
        try:
            result = fetch_detail(page, syllabus_id, raw_dir, retries)
            result.update({"syllabus_id": syllabus_id, "subject_code": item.get("subject_code", "")})
            detail_results[key] = result
        except BlockingDetected as exc:
            detail_results[key] = {
                "status": "blocked",
                "syllabus_id": syllabus_id,
                "subject_code": item.get("subject_code", ""),
                "url": url,
                "attempt_count": retries,
                "error": str(exc),
            }
            record_block_and_stop(
                state_path,
                state,
                stage="fetch",
                subject_code=item.get("subject_code", ""),
                syllabus_id=syllabus_id,
                url=url,
                final_url=url,
                title="",
                reason=str(exc),
            )
        except Exception as exc:  # noqa: BLE001 - one failed syllabus must not stop the crawl.
            detail_results[key] = {
                "status": "failed",
                "syllabus_id": syllabus_id,
                "subject_code": item.get("subject_code", ""),
                "url": url,
                "attempt_count": retries,
                "error": str(exc),
            }
            state["failures"].append(
                asdict(Failure(syllabus_id, item.get("subject_code", ""), "fetch", url, str(exc)))
            )
        if index % 25 == 0:
            print(f"detail crawl {index}/{len(active_items)} active syllabi")
        save_state(state_path, state)
        time.sleep(delay)


def nearest_heading(table) -> str:
    for sibling in table.find_previous_siblings():
        if isinstance(sibling, Tag):
            text = _clean(sibling.get_text(" ", strip=True))
            if text:
                return text
    for node in table.find_all_previous(["h1", "h2", "h3", "h4", "label"], limit=10):
        text = _clean(node.get_text(" ", strip=True))
        if text:
            return text
    return ""


def inspect_unknown_tables(html: str, syllabus_id: int, subject_code: str) -> list[dict[str, Any]]:
    soup = BeautifulSoup(html, "html.parser")
    unknown: list[dict[str, Any]] = []
    for index, table in enumerate(soup.select("table")):
        rows = _table_rows(table)
        if not rows:
            continue
        if _classify_table(rows) is None and len(rows[0]) > 1:
            unknown.append(
                {
                    "syllabus_id": syllabus_id,
                    "subject_code": subject_code,
                    "table_index": index,
                    "headers": rows[0],
                    "nearest_heading": nearest_heading(table),
                    "example_rows": rows[1:4],
                }
            )
    return unknown


def normalize_valid_raw(
    state: dict[str, Any],
    state_path: Path,
    raw_dir: Path,
    normalized_dir: Path,
    report_dir: Path,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    normalized_dir.mkdir(parents=True, exist_ok=True)
    metadata_by_id = {int(key): value for key, value in state.get("active_syllabi", {}).items()}
    active_items = sorted(
        state.get("active_syllabi", {}).items(),
        key=lambda pair: int(pair[0]),
    )
    normalized: list[dict[str, Any]] = []
    parser_failures: list[dict[str, Any]] = []
    unknown_tables: list[dict[str, Any]] = []
    inactive_records: list[dict[str, Any]] = []
    current_syllabus_id: int | None = None
    current_subject_code = ""

    try:
        for index, (key, item) in enumerate(active_items, start=1):
            syllabus_id = int(key)
            current_syllabus_id = syllabus_id
            current_subject_code = item.get("subject_code", "")
            html_path = raw_dir / f"{syllabus_id}.html"
            normalized_path = normalized_dir / f"{syllabus_id}.json"
            url = detail_url(syllabus_id)

            if normalized_path.exists():
                try:
                    normalized.append(json.loads(normalized_path.read_text(encoding="utf-8")))
                except Exception as exc:  # noqa: BLE001 - stale/corrupt normalized output should be visible.
                    parser_failures.append(
                        {
                            "syllabus_id": syllabus_id,
                            "subject_code": current_subject_code,
                            "stage": "normalize",
                            "url": url,
                            "error": f"existing normalized JSON could not be read: {exc}",
                        }
                    )
                continue

            print(f"[{index}/{len(active_items)}] Normalizing SYL-{syllabus_id} {current_subject_code}", flush=True)
            state["normalizing_at"] = {
                "syllabus_id": syllabus_id,
                "subject_code": current_subject_code,
                "raw_path": str(html_path),
            }
            save_state(state_path, state)

            try:
                html = html_path.read_text(encoding="utf-8", errors="replace")
                if not is_valid_syllabus_detail(html, url):
                    raise RuntimeError("raw HTML is not a valid syllabus detail page")
                metadata = metadata_by_id.get(syllabus_id, {})
                parsed = parse_syllabus_html(
                    html,
                    syllabus_id=syllabus_id,
                    source_path=str(html_path.relative_to(PROJECT_ROOT)),
                    index_metadata=metadata,
                )
                data = parsed.to_dict()
                if data.get("active") is False:
                    inactive_records.append(
                        {"syllabus_id": syllabus_id, "subject_code": data.get("subject_code", ""), "source_path": str(html_path)}
                    )
                    continue
                normalized_path.write_text(
                    json.dumps(data, indent=2, ensure_ascii=False),
                    encoding="utf-8",
                )
                normalized.append(data)
                state.setdefault("normalized_results", {})[str(syllabus_id)] = {
                    "status": "normalized",
                    "subject_code": data.get("subject_code", current_subject_code),
                    "normalized_path": str(normalized_path),
                }
                state.pop("normalizing_at", None)
                save_state(state_path, state)
                unknown_tables.extend(inspect_unknown_tables(html, syllabus_id, data.get("subject_code", "")))
            except Exception as exc:  # noqa: BLE001 - parser failures are reported after crawl.
                parser_failures.append(
                    {
                        "syllabus_id": syllabus_id,
                        "subject_code": current_subject_code,
                        "stage": "normalize",
                        "url": url,
                        "error": str(exc),
                    }
                )
    except KeyboardInterrupt:
        print(
            f"STOPPED: KeyboardInterrupt while normalizing SYL-{current_syllabus_id} {current_subject_code}",
            flush=True,
        )
        save_state(state_path, state)
        raise

    write_json(report_dir / "parser_failures.json", parser_failures)
    write_json(report_dir / "unknown_table_structures.json", unknown_tables)
    write_json(report_dir / "inactive_records.json", inactive_records)
    return normalized, parser_failures, unknown_tables, inactive_records


def sqlite_report(db_path: Path, normalized: list[dict[str, Any]]) -> dict[str, Any]:
    import sqlite3

    total_sessions = sum(len(item.get("schedule") or []) for item in normalized)
    with sqlite3.connect(db_path) as connection:
        syllabus_count = connection.execute("SELECT COUNT(*) FROM syllabi").fetchone()[0]
        chunk_count = connection.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        schedule_chunk_count = connection.execute("SELECT COUNT(*) FROM chunks WHERE section = 'schedule'").fetchone()[0]
    return {
        "syllabus_count": syllabus_count,
        "chunk_count": chunk_count,
        "schedule_chunk_count": schedule_chunk_count,
        "normalized_total_session_count": total_sessions,
        "schedule_chunk_session_mismatch_count": 0 if schedule_chunk_count == total_sessions else 1,
        "schedule_chunk_session_match": schedule_chunk_count == total_sessions,
    }


def write_reports(
    report_dir: Path,
    state: dict[str, Any],
    normalized: list[dict[str, Any]],
    parser_failures: list[dict[str, Any]],
    unknown_tables: list[dict[str, Any]],
    inactive_records: list[dict[str, Any]],
    sqlite: dict[str, Any],
) -> None:
    stats = crawl_stats(state)
    fetch_failures = [item for item in state.get("detail_results", {}).values() if item.get("status") == "failed"]
    content = {
        "total_clo_rows": sum(len(item.get("learning_outcomes") or []) for item in normalized),
        "total_assessments": sum(len(item.get("assessments") or []) for item in normalized),
        "total_schedule_sessions": sum(len(item.get("schedule") or []) for item in normalized),
        "total_materials": sum(len(item.get("materials") or []) for item in normalized),
        "total_constructive_questions": sum(len(item.get("constructive_questions") or []) for item in normalized),
    }
    report = {
        "subjects_discovered": stats["discovered_subjects"],
        "subject_prefixes_queried": sorted(state.get("prefix_queries", {})),
        "syllabus_rows_found": stats["syllabus_rows_found"],
        "active_syllabus_ids_selected": stats["unique_active_syllabus_ids"],
        "inactive_syllabi_skipped": stats["inactive_syllabi_skipped"],
        "existing_raw_reused": stats["detail_pages_existing_valid"],
        "new_detail_pages_fetched": stats["detail_pages_fetched"],
        "fetch_failures": len(fetch_failures),
        "normalized_successfully": len(normalized),
        "parser_failures": len(parser_failures),
        "unknown_table_structures": len(unknown_tables),
        "active_false_records": len(inactive_records),
        "content": content,
        "sqlite": sqlite,
        "consistency_pass": sqlite["schedule_chunk_session_match"],
        "failures": state.get("failures", []) + parser_failures,
        "fetch_failure_details": fetch_failures,
        "unknown_table_details": unknown_tables,
        "inactive_record_details": inactive_records,
        "crawl_stats": stats,
    }
    write_json(report_dir / "full_crawl_report.json", report)

    lines = [
        "# Full Active-Only FLM Syllabus Crawl Report",
        "",
        f"Subjects discovered: {report['subjects_discovered']}",
        f"Subject prefixes queried: {len(report['subject_prefixes_queried'])}",
        f"Syllabus rows found: {report['syllabus_rows_found']}",
        f"Active syllabus IDs selected: {report['active_syllabus_ids_selected']}",
        f"Existing raw reused: {report['existing_raw_reused']}",
        f"New detail pages fetched: {report['new_detail_pages_fetched']}",
        f"Fetch failures: {report['fetch_failures']}",
        f"Normalized successfully: {report['normalized_successfully']}",
        f"Parser failures: {report['parser_failures']}",
        f"Unknown table structures: {report['unknown_table_structures']}",
        f"SQLite syllabi: {sqlite['syllabus_count']}",
        f"SQLite chunks: {sqlite['chunk_count']}",
        f"Schedule sessions: {sqlite['normalized_total_session_count']}",
        f"Schedule chunks: {sqlite['schedule_chunk_count']}",
        f"Consistency {'PASS' if report['consistency_pass'] else 'FAIL'}",
        "",
        "## Crawl Stats",
        "",
        "```json",
        json.dumps(stats, indent=2, ensure_ascii=False),
        "```",
        "",
        "## Content Totals",
        "",
        "```json",
        json.dumps(content, indent=2, ensure_ascii=False),
        "```",
        "",
        "## Failures",
        "",
    ]
    failures = report["failures"]
    if failures:
        for failure in failures:
            lines.append(
                f"- {failure.get('stage')} {failure.get('subject_code', '')} "
                f"SYL-{failure.get('syllabus_id')}: {failure.get('error')} ({failure.get('url', '')})"
            )
    else:
        lines.append("- None")
    lines.extend(["", "## Unknown Table Structures", ""])
    if unknown_tables:
        for item in unknown_tables:
            lines.append(f"- {item['subject_code']} SYL-{item['syllabus_id']} table {item['table_index']}: {item['headers']}")
    else:
        lines.append("- None")
    (report_dir / "full_crawl_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cdp-url", default="http://localhost:9222")
    parser.add_argument("--state-path", type=Path, default=PROJECT_ROOT / "data/crawl_state/full_crawl.json")
    parser.add_argument("--report-dir", type=Path, default=PROJECT_ROOT / "data/full_crawl")
    parser.add_argument("--raw-dir", type=Path, default=PROJECT_ROOT / "data/raw/syllabi")
    parser.add_argument("--normalized-dir", type=Path, default=PROJECT_ROOT / "data/normalized/syllabi")
    parser.add_argument("--graph-dir", type=Path, default=PROJECT_ROOT / "data/graph")
    parser.add_argument("--vault-dir", type=Path, default=PROJECT_ROOT / "vault")
    parser.add_argument("--db-path", type=Path, default=PROJECT_ROOT / "data/knowledge.db")
    parser.add_argument("--max-prefix-depth", type=int, default=8)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY_SECONDS)
    parser.add_argument("--resume", action="store_true", help="Resume from data/crawl_state/full_crawl.json")
    parser.add_argument("--raw-fetch-only", action="store_true", help="Only resume the raw detail fetch phase; requires active_syllabi in state")
    parser.add_argument("--normalize-only", action="store_true", help="Normalize existing raw HTML without browser access or detail refetch")
    args = parser.parse_args()

    state = load_state(args.state_path)
    clear_stale_blocked_at(state)
    if not args.normalize_only:
        playwright, browser, context = connect_cdp_context(args.cdp_url)
        page = context.pages[0] if context.pages else context.new_page()
        try:
            page.goto(f"{settings.base_url}/gui/role/student/SyllabusManagement", wait_until="networkidle", timeout=settings.timeout_seconds * 1000)
            if not args.raw_fetch_only:
                subjects = discover_subjects(page, args.state_path, state, args.max_prefix_depth, args.delay)
                print(f"subjects discovered: {len(subjects)}")
                resolve_syllabi(page, args.state_path, state, args.delay)
                print(f"active syllabus IDs selected: {len(state.get('active_syllabi', {}))}")
            crawl_details(page, args.state_path, state, args.raw_dir, args.retries, args.delay)
        except BlockingDetected as exc:
            print(f"STOPPED: {exc}")
            return
        finally:
            browser.close()
            playwright.stop()

    save_state(args.state_path, state)
    try:
        normalized, parser_failures, unknown_tables, inactive_records = normalize_valid_raw(
            state,
            args.state_path,
            args.raw_dir,
            args.normalized_dir,
            args.report_dir,
        )
    except KeyboardInterrupt:
        print("Normalization interrupted; graph/Obsidian/SQLite rebuild skipped.")
        return
    build_graph(normalized_dir=args.normalized_dir, graph_dir=args.graph_dir)
    export_obsidian(normalized_dir=args.normalized_dir, vault_dir=args.vault_dir)
    build_sqlite(normalized_dir=args.normalized_dir, db_path=args.db_path)
    sqlite = sqlite_report(args.db_path, normalized)
    write_reports(args.report_dir, state, normalized, parser_failures, unknown_tables, inactive_records, sqlite)
    print((args.report_dir / "full_crawl_report.md").resolve())


if __name__ == "__main__":
    main()
