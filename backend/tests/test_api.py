from __future__ import annotations

import asyncio

from app.db import connect
from app.main import health
from app.services.graph import graph_for_subject
from app.services.retrieval import retrieve
from app.services.search import search_chunks
from app.services.subjects import get_schedule, get_subject, list_subjects


def test_health():
    response = asyncio.run(health())
    assert response["status"] == "ok"
    assert response["knowledge_db"] is True


def test_subjects():
    with connect() as db:
        response = list_subjects(db)
    assert response.items


def test_subject_case_insensitive():
    with connect() as db:
        upper = get_subject(db, "JPD111")
        lower = get_subject(db, "jpd111")
    assert upper is not None
    assert lower is not None
    assert upper.code == lower.code == "JPD111"


def test_schedule_session():
    with connect() as db:
        rows = get_schedule(db, "JPD111", session_number=9)
    assert rows
    assert rows[0].session_number == 9


def test_search_hiragana():
    with connect() as db:
        response = search_chunks(db, "hiragana")
    assert response


def test_retrieve_assessment():
    with connect() as db:
        response = retrieve(db, "JPD111 assessment")
    assert response.intent == "assessment"
    assert response.results


def test_retrieve_session_9():
    with connect() as db:
        response = retrieve(db, "JPD111 session 9")
    assert response.intent == "schedule"
    assert response.results[0].session_number == 9


def test_retrieve_hiragana_question():
    with connect() as db:
        response = retrieve(db, "JPD111 học hiragana ở buổi nào")
    assert response.intent == "schedule"
    assert response.results


def test_retrieve_prerequisite_mixed_case():
    with connect() as db:
        response = retrieve(db, "AIS301C prerequisite")
    assert response.subject_code == "AIS301C"
    assert response.intent == "prerequisite"


def test_retrieve_vietnamese_intents():
    with connect() as db:
        res_credits = retrieve(db, "môn PRM393 có mấy tín chỉ")
        assert res_credits.subject_code == "PRM393"
        assert res_credits.intent == "general_information"

        res_grade = retrieve(db, "cách tính điểm môn SWP391")
        assert res_grade.subject_code == "SWP391"
        assert res_grade.intent == "assessment"

        res_prereq = retrieve(
            db,
            "nếu rớt môn SWE201c thì các kỳ sau sẽ không được học những môn nào",
        )
        assert res_prereq.subject_code == "SWE201C"
        assert res_prereq.intent == "prerequisite"


def test_graph_subject():
    response = graph_for_subject("JPD111")
    assert any(node.label == "JPD111" for node in response.nodes)


def test_prerequisite_graph_is_directed_and_reaches_jpd326_chain():
    response = graph_for_subject("JPD326", depth=3)
    edges = {(edge.source, edge.target) for edge in response.edges}

    assert ("subject:JPD133", "subject:OJT202") in edges
    assert ("subject:OJT202", "subject:JPD316") in edges
    assert ("subject:JPD316", "subject:JPD326") in edges
    assert all(edge.type == "REQUIRES_PREREQUISITE" for edge in response.edges)
    assert next(node for node in response.nodes if node.label == "JPD326").name
    assert all(node.label != "AIP490" for node in response.nodes)
