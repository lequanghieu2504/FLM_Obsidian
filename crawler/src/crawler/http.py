from __future__ import annotations

import time
from collections.abc import Callable
from typing import TypeVar

import requests

from src.config import settings

T = TypeVar("T")


def retry(operation: Callable[[], T], attempts: int | None = None) -> T:
    last_error: Exception | None = None
    for attempt in range(1, (attempts or settings.max_retries) + 1):
        try:
            return operation()
        except (requests.RequestException, TimeoutError) as exc:
            last_error = exc
            if attempt < (attempts or settings.max_retries):
                time.sleep(settings.delay_seconds * attempt)
    assert last_error is not None
    raise last_error


def polite_pause() -> None:
    time.sleep(settings.delay_seconds)

