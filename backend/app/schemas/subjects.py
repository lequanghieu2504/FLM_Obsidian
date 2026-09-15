from __future__ import annotations

from pydantic import BaseModel


class SubjectSummary(BaseModel):
    code: str
    name: str


class SubjectList(BaseModel):
    items: list[SubjectSummary]
    page: int
    page_size: int
    total: int


class SyllabusSummary(BaseModel):
    syllabus_id: int
    subject_code: str
    subject_name: str
    syllabus_name: str
    active: bool | None
    approved: bool | None
    decision: str
    description: str
    source_path: str
    credits: str | None = None
    degree_level: str | None = None
    time_allocation: str | None = None
    prerequisite: str | None = None


class SubjectDetail(BaseModel):
    code: str
    name: str
    syllabi: list[SyllabusSummary]
    learning_outcomes: list[dict[str, str]]
    assessment: list[dict[str, str]]
    materials: list[dict[str, str]]


class ScheduleItem(BaseModel):
    subject_code: str
    syllabus_id: int | None
    session_number: int | None
    title: str
    content: str
