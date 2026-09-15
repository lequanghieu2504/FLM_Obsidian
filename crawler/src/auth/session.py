from __future__ import annotations

from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup


def looks_like_login_page(text: str, url: str = "") -> bool:
    path = urlparse(url).path.lower()
    if path in {"/login", "/home/login"} or path.endswith("/login"):
        return True
    soup = BeautifulSoup(text, "html.parser")
    return soup.select_one("input[type='password']") is not None


def looks_like_cloudflare_challenge(text: str, title: str = "") -> bool:
    if "just a moment" in title.lower():
        return True
    soup = BeautifulSoup(text, "html.parser")
    selectors = (
        "#challenge-form",
        ".cf-browser-verification",
        ".cf-challenge",
        "[id^='cf-chl']",
        "[class*='cf-chl']",
        "[name='cf-turnstile-response']",
        "script[src*='challenges.cloudflare.com']",
    )
    return any(soup.select_one(selector) is not None for selector in selectors)


def looks_like_syllabus_management(text: str, url: str = "") -> bool:
    soup = BeautifulSoup(text, "html.parser")
    has_details = soup.find(string=lambda value: bool(value and "Syllabus Details" in value)) is not None
    heading_is_management = any(
        heading.get_text(" ", strip=True) == "Syllabus Management"
        for heading in soup.find_all(["h1", "h2", "h3"])
    )
    return heading_is_management or (soup.select_one("#gvSyllabus") is not None and not has_details)


def direct_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 FLM-Obsidian-Lab/1.0",
            "Accept": "text/html,application/json;q=0.9,*/*;q=0.8",
        }
    )
    return session


def connect_cdp_context(cdp_url: str = "http://localhost:9222"):
    try:
        from playwright.sync_api import Error as PlaywrightError
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError("Install Playwright and run `playwright install chromium`.") from exc

    playwright = sync_playwright().start()
    try:
        browser = playwright.chromium.connect_over_cdp(cdp_url)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        return playwright, browser, context
    except PlaywrightError as exc:
        playwright.stop()
        raise RuntimeError(
            "Could not attach to Chrome CDP at http://localhost:9222. "
            "Start Chrome manually with `google-chrome --remote-debugging-port=9222 "
            "--user-data-dir=\"$HOME/.flm-crawler-chrome\"`, then complete FEID login there."
        ) from exc
