from __future__ import annotations

import sqlite3
from collections.abc import AsyncIterator

from .config import KNOWLEDGE_DB


def connect() -> sqlite3.Connection:
    uri = f"file:{KNOWLEDGE_DB}?mode=ro"
    connection = sqlite3.connect(uri, uri=True, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    return connection


async def get_db() -> AsyncIterator[sqlite3.Connection]:
    connection = connect()
    try:
        yield connection
    finally:
        connection.close()
