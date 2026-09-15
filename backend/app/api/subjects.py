from __future__ import annotations

import sqlite3

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..schemas.subjects import ScheduleItem, SubjectDetail, SubjectList
from ..services.subjects import get_schedule, get_subject, list_subjects


router = APIRouter(prefix="/api/subjects", tags=["subjects"])


@router.get("", response_model=SubjectList)
async def subjects(
    q: str = "",
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: sqlite3.Connection = Depends(get_db),
) -> SubjectList:
    return list_subjects(db, q=q, page=page, page_size=page_size)


@router.get("/{subject_code}", response_model=SubjectDetail)
async def subject_detail(subject_code: str, db: sqlite3.Connection = Depends(get_db)) -> SubjectDetail:
    subject = get_subject(db, subject_code)
    if subject is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    return subject


@router.get("/{subject_code}/schedule", response_model=list[ScheduleItem])
async def schedule(subject_code: str, db: sqlite3.Connection = Depends(get_db)) -> list[ScheduleItem]:
    rows = get_schedule(db, subject_code)
    if rows is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    return rows


@router.get("/{subject_code}/schedule/{session_number}", response_model=ScheduleItem)
async def schedule_item(subject_code: str, session_number: int, db: sqlite3.Connection = Depends(get_db)) -> ScheduleItem:
    rows = get_schedule(db, subject_code, session_number=session_number)
    if rows is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    if not rows:
        raise HTTPException(status_code=404, detail="Session not found")
    return rows[0]
