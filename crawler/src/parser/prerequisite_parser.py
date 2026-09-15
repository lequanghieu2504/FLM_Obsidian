from __future__ import annotations

import re


_CODE_RE = re.compile(r"(?<![A-Za-z0-9])([A-Za-zĐđ]{2,6}\d{2,3}[A-Za-z]?)(?![A-Za-z0-9])")
_EMPTY_VALUES = {"", "khong", "không", "n/a", "na", "nil", "no", "none", "none."}


def _normalize_code(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9Đđ]", "", value).upper()


def extract_prerequisite_codes(prerequisite: str, subject_codes: set[str]) -> list[str]:
    """Extract known subject codes mentioned in a prerequisite field."""
    text = prerequisite.strip()
    if _normalize_text(text) in _EMPTY_VALUES:
        return []

    known_by_normalized = {_normalize_code(code): code for code in subject_codes}
    ordered: list[str] = []

    for match in _CODE_RE.finditer(text):
        candidate = match.group(1)
        normalized = _normalize_code(candidate)
        resolved = _resolve_code(normalized, known_by_normalized)
        for code in resolved:
            if code not in ordered:
                ordered.append(code)

    return ordered


def format_prerequisite_links(prerequisite: str, codes: list[str]) -> str:
    linked = prerequisite
    for code in sorted(codes, key=len, reverse=True):
        linked = re.sub(
            rf"(?<![A-Za-z0-9])({re.escape(code)})(?![A-Za-z0-9])",
            r"[[\1]]",
            linked,
            flags=re.IGNORECASE,
        )
    return linked


def _resolve_code(normalized: str, known_by_normalized: dict[str, str]) -> list[str]:
    exact = known_by_normalized.get(normalized)
    if exact:
        return [exact]

    if normalized.endswith("X"):
        prefix = normalized[:-1]
        return sorted(code for key, code in known_by_normalized.items() if key.startswith(prefix))

    return []


def _normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())
