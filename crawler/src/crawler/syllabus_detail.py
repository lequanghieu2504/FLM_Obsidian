from __future__ import annotations

import json
from pathlib import Path

import requests
from bs4 import BeautifulSoup

from src.auth.session import (
    connect_cdp_context,
    looks_like_cloudflare_challenge,
    looks_like_login_page,
    looks_like_syllabus_management,
)
from src.config import PROJECT_ROOT, settings
from src.crawler.http import polite_pause, retry


def _merge_crawl_stats(stats_path: Path, updates: dict[str, int]) -> dict:
    stats = json.loads(stats_path.read_text(encoding="utf-8")) if stats_path.exists() else {}
    for key, value in updates.items():
        stats[key] = int(stats.get(key, 0)) + value
    stats_path.parent.mkdir(parents=True, exist_ok=True)
    stats_path.write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf-8")
    return stats


def is_valid_syllabus_detail(html: str, url: str = "") -> bool:
    if looks_like_login_page(html, url):
        return False
    if looks_like_cloudflare_challenge(html):
        return False
    if looks_like_syllabus_management(html, url):
        return False
    return _has_valid_syllabus_detail_signals(html, url)


def _has_valid_syllabus_detail_signals(html: str, url: str, syllabus_id: int | None = None) -> bool:
    if "/gui/role/student/syllabusdetails" not in url.lower():
        return False
    soup = BeautifulSoup(html, "html.parser")
    page_text = soup.get_text(" ", strip=True)
    has_details_heading = "Syllabus Details" in page_text
    has_id_label = "Syllabus ID:" in page_text
    has_requested_id = syllabus_id is None or str(syllabus_id) in page_text
    return has_details_heading and has_id_label and has_requested_id


def detect_heading(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for heading in soup.find_all(["h1", "h2", "h3"]):
        text = heading.get_text(" ", strip=True)
        if text == "Syllabus Details":
            return text
    for heading in soup.find_all(["h1", "h2", "h3"]):
        text = heading.get_text(" ", strip=True)
        if text:
            return text
    match = soup.find(string=lambda value: bool(value and "Syllabus Details" in value))
    return str(match).strip() if match else ""


def download_syllabus_detail_via_cdp(
    syllabus_id: int,
    cdp_url: str = "http://localhost:9222",
    output_dir: Path | None = None,
) -> dict:
    destination = output_dir or PROJECT_ROOT / "data/raw/syllabi"
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"{syllabus_id}.html"
    playwright, browser, context = connect_cdp_context(cdp_url)
    page = context.pages[0] if context.pages else context.new_page()
    url = f"{settings.base_url}/gui/role/student/SyllabusDetails?sylID={syllabus_id}"
    try:
        page.goto(url, wait_until="networkidle", timeout=settings.timeout_seconds * 1000)
        html = page.content()
        final_url = page.url
        title = page.title()
        if looks_like_login_page(html, final_url):
            raise RuntimeError("Loaded page is Login; complete FEID login in the CDP Chrome instance first.")
        if looks_like_cloudflare_challenge(html, title):
            raise RuntimeError("Loaded page is a Cloudflare challenge; resolve it in the CDP Chrome instance first.")
        if looks_like_syllabus_management(html, final_url):
            raise RuntimeError("Loaded page is Syllabus Management, not Syllabus Details.")
        if not _has_valid_syllabus_detail_signals(html, final_url, syllabus_id):
            raise RuntimeError("Loaded page does not look like a valid syllabus detail page.")
        target.write_text(html, encoding="utf-8")
        return {
            "final_url": final_url,
            "title": title,
            "heading": detect_heading(html),
            "html_bytes": len(html.encode("utf-8")),
            "raw_path": str(target),
        }
    finally:
        browser.close()
        playwright.stop()


def download_syllabus_details(
    session: requests.Session,
    syllabi_path: Path | None = None,
    output_dir: Path | None = None,
    errors_path: Path | None = None,
) -> list[dict]:
    syllabi_file = syllabi_path or PROJECT_ROOT / "data/index/syllabi.json"
    destination = output_dir or PROJECT_ROOT / "data/raw/syllabi"
    errors_file = errors_path or PROJECT_ROOT / "data/index/errors.json"
    stats_file = errors_file.with_name("crawl_stats.json")
    syllabi = json.loads(syllabi_file.read_text(encoding="utf-8"))
    destination.mkdir(parents=True, exist_ok=True)
    errors: list[dict] = []
    detail_pages_fetched = 0

    for item in syllabi:
        syllabus_id = int(item["syllabus_id"])
        if item.get("is_active") is not True:
            print(f"{item.get('subject_code', '')}: skip inactive syllabus {syllabus_id} before detail fetch")
            continue
        target = destination / f"{syllabus_id}.html"
        if target.exists() and is_valid_syllabus_detail(target.read_text(encoding="utf-8", errors="replace")):
            continue

        url = item.get("detail_url") or f"{settings.base_url}/gui/role/student/SyllabusDetails?sylID={syllabus_id}"
        try:
            response = retry(lambda url=url: session.get(url, timeout=settings.timeout_seconds))
            response.raise_for_status()
            if not is_valid_syllabus_detail(response.text, response.url):
                raise ValueError("Downloaded response does not look like a syllabus detail page")
            target.write_text(response.text, encoding="utf-8")
            detail_pages_fetched += 1
        except Exception as exc:  # noqa: BLE001 - errors are recorded for lab review.
            errors.append({"syllabus_id": syllabus_id, "url": url, "error": str(exc)})
        polite_pause()

    errors_file.parent.mkdir(parents=True, exist_ok=True)
    errors_file.write_text(json.dumps(errors, indent=2, ensure_ascii=False), encoding="utf-8")
    stats = _merge_crawl_stats(stats_file, {"detail_pages_fetched": detail_pages_fetched})
    print(f"crawl_stats: {json.dumps(stats, ensure_ascii=False)}")
    return errors
