# CODEX_SETUP.md

# 1. Objective

Build a 3-week lab project for FPT University students.

The system must:

1. crawl course/syllabus data from FPT FLM using Python;
2. preserve raw HTML;
3. normalize the data into structured JSON;
4. generate an Obsidian-compatible Markdown knowledge base;
5. build a local SQLite/FTS5 search index;
6. provide a Flutter Desktop application for browsing/searching courses;
7. provide a chatbox that retrieves relevant local knowledge and calls an LLM using BYOK.

Core architecture:

```text
FLM
→ Python crawler
→ raw HTML
→ normalized JSON
→ {Obsidian Markdown + SQLite FTS5}
→ Flutter Desktop
→ local retrieval
→ BYOK LLM
→ answer
```

Do not over-engineer.

---

# 2. Final Technology Stack

## Data pipeline

Use:

```text
Python 3.11+
requests
beautifulsoup4
playwright
pydantic
tqdm
pyyaml
sqlite3 (stdlib)
```

Install:

```bash
python -m venv .venv
source .venv/bin/activate

pip install \
  requests \
  beautifulsoup4 \
  playwright \
  pydantic \
  tqdm \
  pyyaml

playwright install chromium
```

Playwright is used only when browser-assisted authentication/session acquisition is necessary.

---

## Flutter desktop application

Use:

```text
Flutter
Dart
Riverpod
go_router
drift or sqlite3_flutter_libs
flutter_secure_storage
http
```

Recommended dependencies:

```bash
flutter pub add flutter_riverpod
flutter pub add go_router
flutter pub add http
flutter pub add flutter_secure_storage
flutter pub add drift
flutter pub add sqlite3_flutter_libs
flutter pub add path_provider
```

Optional:

```text
Firebase
```

Firebase is NOT required for the MVP.

---

# 3. Project Structure

```text
fptu-syllabus-lab/
│
├── crawler/
│   ├── requirements.txt
│   ├── main.py
│   └── src/
│       ├── config.py
│       ├── auth/
│       │   └── session.py
│       ├── crawler/
│       │   ├── subject_discovery.py
│       │   ├── syllabus_index.py
│       │   ├── syllabus_detail.py
│       │   ├── curriculum.py
│       │   └── prerequisite.py
│       ├── parser/
│       │   ├── syllabus_parser.py
│       │   ├── curriculum_parser.py
│       │   └── relation_parser.py
│       ├── models/
│       │   ├── subject.py
│       │   ├── syllabus.py
│       │   └── graph.py
│       ├── graph/
│       │   └── builder.py
│       ├── indexer/
│       │   └── sqlite_indexer.py
│       └── exporter/
│           └── obsidian.py
│
├── data/
│   ├── raw/
│   │   ├── syllabi/
│   │   ├── curricula/
│   │   └── relations/
│   ├── normalized/
│   │   ├── subjects/
│   │   ├── syllabi/
│   │   └── curricula/
│   ├── graph/
│   │   ├── nodes.jsonl
│   │   └── edges.jsonl
│   ├── index/
│   │   ├── subjects.json
│   │   ├── syllabi.json
│   │   └── errors.json
│   └── knowledge.db
│
├── vault/
│   ├── Subjects/
│   ├── Syllabi/
│   ├── Curricula/
│   ├── Materials/
│   └── Index/
│
├── app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── services/
│   │   │   ├── retrieval_service.dart
│   │   │   ├── llm_service.dart
│   │   │   └── key_storage_service.dart
│   │   └── features/
│   │       ├── subjects/
│   │       ├── syllabus/
│   │       ├── search/
│   │       ├── chatbot/
│   │       └── settings/
│   └── pubspec.yaml
│
├── .env.example
├── .gitignore
├── CODEX_SETUP.md
├── IMPLEMENTATION_PLAN.md
├── PROJECT_CONTEXT.md
└── USER_INPUTS_REQUIRED.md
```

---

# 4. Confirmed FLM Endpoints

Base URL:

```text
https://flm.fpt.edu.vn
```

## Subject autocomplete

```text
GET /api/ListSubjectCodeHandler.ashx?term=<prefix>
```

Observed example:

```text
/api/ListSubjectCodeHandler.ashx?term=JPD
```

Response is a JSON array of subject codes.

Observed examples include:

```text
JPD111
JPD112
JPD113
...
```

Important:

A one-letter query such as:

```text
term=A
```

appeared to return approximately 30 items.

Therefore the endpoint may cap results.

Do not assume one prefix query is complete.

Use recursive prefix expansion when a response reaches the suspected cap.

---

## Syllabus search

```text
GET /gui/role/student/SyllabusManagement
```

Query:

```text
searchOn=Code
keyword=<subject_code>
```

The returned HTML contains:

```text
#gvSyllabus
```

Columns observed:

```text
Syllabus ID
Subject Code
Subject Name
Syllabus Name
IsActive
IsApproved
DecisionNo
```

Known example:

```text
JPD111
→ syllabus ID 998
```

Detail link:

```text
/gui/role/student/SyllabusDetails?sylID=998
```

---

## Potential relation pages already observed

```text
/gui/tool/CurriculumOfSubject.aspx
/gui/tool/AllPrequisiteSubject.aspx
/gui/tool/AllCorollarySubject.aspx
```

Do not guess request parameters.

Inspect actual browser requests before implementing these crawlers.

---

# 5. Authentication Strategy

Do not hardcode FEID credentials.

Preferred flow:

```text
Playwright browser
→ user logs in manually
→ authenticated cookies/session are obtained
→ Python requests.Session reuses those cookies
→ crawler downloads authorized FLM pages
```

If the student pages are accessible without auth for the required data, skip Playwright.

Never commit:

```text
username
password
cookies
session tokens
LLM API keys
Firebase service account secrets
```

---

# 6. Crawl Pipeline

Use this separation:

```text
FLM
→ raw HTML
→ normalized JSON
→ graph
→ Obsidian
→ SQLite FTS5
```

Do not:

```text
FLM → Markdown directly
```

Raw HTML is preserved so parser logic can be changed without re-crawling.

---

# 7. Subject Discovery

Use recursive prefix discovery against:

```text
/api/ListSubjectCodeHandler.ashx
```

Pseudo-logic:

```text
query(prefix)

if result count < suspected cap:
    accept branch
else:
    expand prefix with next characters
```

Candidate characters:

```text
A-Z
a-z
0-9
_
-
```

Output:

```text
data/index/subjects.json
```

Requirements:

```text
deduplicate
retry
checkpoint
logging
polite throttling
```

---

# 8. Syllabus Discovery

For every subject code:

```text
GET /gui/role/student/SyllabusManagement
    ?searchOn=Code
    &keyword=<subject_code>
```

Parse:

```text
#gvSyllabus
```

Extract:

```text
syllabus_id
subject_code
subject_name
syllabus_name
is_active
is_approved
decision
detail_url
```

Keep all syllabus versions.

Canonical IDs:

```text
subject:JPD111
syllabus:998
```

Output:

```text
data/index/syllabi.json
```

---

# 9. Raw Syllabus Download

For every discovered syllabus ID:

```text
GET /gui/role/student/SyllabusDetails?sylID=<id>
```

Save:

```text
data/raw/syllabi/<id>.html
```

Requirements:

```text
resume-safe
retry transient errors
skip valid existing file
session expiry detection
1–2 requests/second
error log
```

Validate the downloaded page is actually the detail page and not:

```text
login page
syllabus management page
generic error page
```

---

# 10. Normalized Data

Use JSON as the machine-readable source of truth.

Example syllabus:

```json
{
  "id": "syllabus:998",
  "syllabus_id": 998,
  "subject_code": "JPD111",
  "subject_name": "Elementary Japanese 1.1",
  "syllabus_name": "Tiếng Nhật sơ cấp 1.1",
  "active": true,
  "approved": true,
  "decision": "...",
  "description": "",
  "learning_outcomes": [],
  "assessments": [],
  "schedule": [],
  "materials": []
}
```

Do not invent selectors before inspecting real `SyllabusDetails` HTML.

---

# 11. Knowledge Graph

Standalone node types:

```text
Subject
Syllabus
Curriculum
Material
```

Relations:

```text
Subject --HAS_SYLLABUS--> Syllabus
Curriculum --CONTAINS--> Subject
Subject --PREREQUISITE_OF--> Subject
Syllabus --USES_MATERIAL--> Material
```

Keep:

```text
learning outcomes
assessment items
schedule sessions
```

inside syllabus content instead of making every item a standalone graph node.

---

# 12. Obsidian Export

Generate:

```text
vault/
├── Subjects/
├── Syllabi/
├── Curricula/
├── Materials/
└── Index/
```

Example subject note:

```markdown
---
id: subject:SWP391
type: subject
code: SWP391
---

# SWP391

## Syllabus Versions

- [[SYL-1832]]

## Prerequisites

- [[SWE201c]]

## Curricula

- [[BIT-SE-K20]]
```

Obsidian is:

```text
human-readable knowledge base
knowledge graph visualization
debug/reference representation
```

Obsidian is NOT the application's primary database.

---

# 13. SQLite / FTS5

Build:

```text
data/knowledge.db
```

Recommended tables:

```text
subjects
syllabi
curricula
relations
chunks
```

Example `chunks` fields:

```text
id
subject_code
syllabus_id
section
title
content
source_path
```

Recommended sections:

```text
overview
description
learning_outcomes
assessment
schedule
materials
prerequisites
curriculum
```

Use SQLite FTS5 for text retrieval.

Example conceptual query:

```sql
SELECT *
FROM chunks_fts
WHERE chunks_fts MATCH ?
LIMIT 5;
```

The Flutter application should read SQLite rather than parse the entire Markdown vault.

---

# 14. Retrieval Strategy

For the 3-week MVP, use structured retrieval first.

Example question:

```text
SWP391 final exam bao nhiêu phần trăm?
```

Pipeline:

```text
detect subject_code = SWP391
detect intent = assessment
filter chunks by subject_code + section
rank with FTS5 if necessary
select top context
call LLM
```

This is preferred over immediately introducing a vector database.

Optional upgrade:

```text
hybrid keyword + embedding retrieval
```

Not required.

---

# 15. Flutter Desktop

Minimum screens:

```text
Home
Subjects
Subject Detail
Syllabus Detail
Search
Chat
Settings
```

Architecture:

```text
Widget
↓
Riverpod
↓
Repository
↓
SQLite
```

Do not embed SQL queries directly throughout widgets.

---

# 16. BYOK

BYOK:

```text
Bring Your Own Key
```

Settings should support:

```text
Provider
Base URL
API Key
Model
```

Possible provider architecture:

```dart
abstract class LlmProvider {
  Future<String> chat({
    required String apiKey,
    required String model,
    required String question,
    required String context,
  });
}
```

Implement only one provider first.

Recommended starting point:

```text
OpenAI-compatible endpoint
```

This can later support OpenRouter or compatible services via configurable Base URL.

---

# 17. API Key Security

Use:

```text
flutter_secure_storage
```

Never store user LLM API keys in:

```text
Git
source code
Firestore
SQLite knowledge database
plain SharedPreferences
logs
```

---

# 18. Chat Flow

```text
User question
↓
RetrievalService
↓
SQLite structured filter / FTS5
↓
relevant chunks
↓
prompt builder
↓
BYOK LLM API
↓
answer
```

Prompt rule:

```text
Answer from the supplied course context.
If the information is not present, explicitly say it is unavailable.
Do not invent syllabus information.
```

---

# 19. Firebase

Firebase is optional.

Only add it if needed for:

```text
user login
cloud chat history
favorites
remote sync
multi-device preferences
```

Do NOT use Firebase merely because it is available.

For MVP:

```text
Flutter + local SQLite + BYOK
```

is enough.

---

# 20. Definition of Done

The project is complete when:

1. Python discovers subject codes.
2. Python discovers syllabus IDs.
3. Raw syllabus HTML is cached.
4. Main syllabus data is normalized to JSON.
5. Main relationships are represented.
6. Obsidian Markdown is generated.
7. SQLite/FTS5 index is generated.
8. Flutter Desktop can browse/search subjects.
9. User can configure an LLM provider using BYOK.
10. Chat retrieves relevant local knowledge before calling the LLM.
11. LLM answers from retrieved syllabus context.
