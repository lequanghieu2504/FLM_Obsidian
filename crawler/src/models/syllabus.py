from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True)
class SyllabusIndexItem:
    syllabus_id: int
    subject_code: str
    subject_name: str
    syllabus_name: str
    is_active: bool | None
    is_approved: bool | None
    decision: str
    detail_url: str

    @property
    def canonical_id(self) -> str:
        return f"syllabus:{self.syllabus_id}"

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["id"] = self.canonical_id
        return data


@dataclass
class NormalizedSyllabus:
    syllabus_id: int
    subject_code: str
    subject_name: str = ""
    syllabus_name: str = ""
    credits: int | None = None
    degree_level: str = ""
    time_allocation: str = ""
    prerequisite: str = ""
    general_information: dict[str, Any] = field(default_factory=dict)
    active: bool | None = None
    approved: bool | None = None
    decision: str = ""
    description: str = ""
    learning_outcomes: list[dict[str, Any]] = field(default_factory=list)
    assessments: list[dict[str, Any]] = field(default_factory=list)
    schedule: list[dict[str, Any]] = field(default_factory=list)
    constructive_questions: list[dict[str, Any]] = field(default_factory=list)
    materials: list[dict[str, Any]] = field(default_factory=list)
    source_path: str = ""

    @property
    def id(self) -> str:
        return f"syllabus:{self.syllabus_id}"

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["id"] = self.id
        return data
