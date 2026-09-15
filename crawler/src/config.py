from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ROOT = PROJECT_ROOT / "crawler"


def _float_env(name: str, default: float) -> float:
    value = os.getenv(name)
    return default if value is None else float(value)


def _int_env(name: str, default: int) -> int:
    value = os.getenv(name)
    return default if value is None else int(value)


@dataclass(frozen=True)
class Settings:
    base_url: str = os.getenv("FLM_BASE_URL", "https://flm.fpt.edu.vn").rstrip("/")
    delay_seconds: float = _float_env("CRAWL_DELAY_SECONDS", 0.7)
    timeout_seconds: int = _int_env("CRAWL_TIMEOUT_SECONDS", 30)
    max_retries: int = _int_env("CRAWL_MAX_RETRIES", 3)
    profile_dir: Path = (ROOT / os.getenv("FLM_PROFILE_DIR", "../secrets/flm_profile")).resolve()


settings = Settings()
