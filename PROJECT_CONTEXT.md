# PROJECT_CONTEXT.md

# 1. Project Background

This is a three-week lab.

The application is intended for FPT University students.

Main idea:

```text
collect FLM syllabus/course information
→ turn it into a structured local knowledge base
→ visualize it in Obsidian
→ browse it in Flutter Desktop
→ ask questions through an LLM chatbox
```

---

# 2. Final Architecture Decision

The agreed architecture is:

```text
FLM
→ Python crawler
→ raw HTML
→ normalized JSON
→ graph
→ Obsidian Markdown
→ SQLite FTS5
→ Flutter Desktop
→ local retrieval
→ BYOK LLM
```

Firebase is optional.

---

# 3. Responsibility by Technology

## Python

Python handles all offline data work:

```text
crawl
parse
normalize
build graph
generate Markdown
build SQLite/FTS5 index
```

Reason:

```text
fastest implementation for a 3-week lab
strong HTML/data-processing ecosystem
```

---

## JSON

Normalized JSON is the machine-readable source of truth.

Reason:

```text
easy to validate
easy to regenerate outputs
not tied to Obsidian or Flutter
```

---

## Obsidian / Markdown

Obsidian is a human-readable representation of the same knowledge.

Use cases:

```text
manual inspection
knowledge graph visualization
debugging relations
demonstration
```

Obsidian is NOT the primary runtime database for Flutter.

---

## SQLite / FTS5

SQLite is the runtime knowledge store for Flutter.

Reason:

```text
local
fast
simple
no backend required
works offline
supports FTS5
easy to package with desktop app
```

---

## Flutter / Dart

Flutter is the end-user application.

Responsibilities:

```text
browse subjects
search
view syllabus
view relationships
chatbox
settings
BYOK provider configuration
```

---

## BYOK LLM

BYOK:

```text
Bring Your Own Key
```

The app does not provide a shared commercial LLM key.

The user supplies:

```text
API key
provider/base URL
model
```

The key stays on the user's device.

---

## Firebase

Firebase is optional.

Only add Firebase if the lab actually needs:

```text
login
remote synchronization
cloud chat history
favorites
multi-device preferences
```

It is not needed for the crawler or local knowledge retrieval.

---

# 4. Confirmed FLM Behavior

Base URL:

```text
https://flm.fpt.edu.vn
```

## Subject autocomplete

Confirmed endpoint:

```text
/api/ListSubjectCodeHandler.ashx
```

Request:

```text
?term=<prefix>
```

Observed response for `JPD`:

```json
[
  "JPD111",
  "JPD112",
  "JPD113",
  "JPD116",
  "JPD121",
  "JPD122",
  "JPD123",
  "JPD126",
  "JPD131",
  "JPD133",
  "JPD141",
  "JPD216",
  "JPD222",
  "JPD223",
  "JPD226",
  "JPD316",
  "JPD322",
  "JPD323",
  "JPD324",
  "JPD325",
  "JPD326",
  "JPD336",
  "JPD346"
]
```

A query for:

```text
term=A
```

returned approximately 30 subject codes.

Inference:

```text
autocomplete may cap results
```

Use recursive prefixes instead of assuming one query is complete.

---

# 5. Confirmed Syllabus Search

Endpoint:

```text
/gui/role/student/SyllabusManagement
```

Method:

```text
GET
```

Parameters:

```text
searchOn=Code
keyword=<subject_code>
```

Returned table:

```text
#gvSyllabus
```

Observed fields:

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

Detail:

```text
/gui/role/student/SyllabusDetails?sylID=998
```

---

# 6. Important Entity Rule

A subject and syllabus version are different entities.

Correct:

```text
subject:JPD111
syllabus:998
```

A subject may have multiple syllabus versions.

Do not overwrite all versions into one note/data object.

---

# 7. Graph Model

Primary nodes:

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

Keep these inside syllabus content:

```text
learning outcomes
assessment items
schedule sessions
```

unless a later requirement needs them as nodes.

---

# 8. Raw Data Rule

Always preserve raw server responses.

Correct:

```text
FLM
→ raw HTML
→ parser
→ normalized JSON
```

This allows parser changes without re-crawling.

---

# 9. Obsidian Model

Example:

```text
vault/
├── Subjects/SWP391.md
├── Subjects/SWE201c.md
├── Syllabi/SYL-1832.md
└── Curricula/BIT-SE-K20.md
```

Links:

```text
SWP391
→ SWE201c
→ SYL-1832
→ BIT-SE-K20
```

Example note:

```markdown
# SWP391

## Prerequisites

- [[SWE201c]]

## Syllabus Versions

- [[SYL-1832]]
```

---

# 10. Why SQLite Instead of Direct Markdown Runtime

Do not make Flutter:

```text
scan hundreds/thousands of Markdown files
parse YAML
resolve all wikilinks
perform ad-hoc text search
```

Python already has normalized data.

Build:

```text
knowledge.db
```

Flutter uses that.

Obsidian remains a visualization/human-readable output.

---

# 11. Suggested SQLite Data

Tables:

```text
subjects
syllabi
curricula
relations
chunks
```

`chunks` contains semantic retrieval units.

Example:

```json
{
  "subject_code": "SWP391",
  "syllabus_id": 1832,
  "section": "assessment",
  "content": "...",
  "source_path": "Syllabi/SYL-1832.md"
}
```

---

# 12. Retrieval Design

For this domain, structured retrieval is more important than vector search.

Many questions explicitly contain a code:

```text
SWP391
JPD111
PRN212
```

Example:

```text
SWP391 final bao nhiêu %?
```

Preferred process:

```text
detect SWP391
→ detect assessment intent
→ filter subject_code=SWP391
→ filter section=assessment
→ FTS5 rank if needed
→ send only relevant context to LLM
```

No vector DB is required for MVP.

---

# 13. Chatbot Rule

Do not send the whole knowledge base to the LLM.

Flow:

```text
question
→ retrieve relevant local content
→ construct context
→ LLM
```

Prompt must instruct:

```text
use only provided context
do not invent syllabus facts
say when information is unavailable
```

---

# 14. BYOK Security

Do not store LLM API keys in:

```text
Git
Firebase
SQLite
plain config files
logs
```

Use:

```text
flutter_secure_storage
```

For desktop development, an environment variable may be used temporarily, but production/demo user BYOK should use secure storage.

---

# 15. Current Unknowns

Still require actual inspection:

```text
exact SyllabusDetails DOM
learning outcome selectors
assessment selectors
schedule selectors
material selectors
curriculum request parameters
prerequisite request parameters
exact autocomplete cap
```

Codex must inspect real responses instead of inventing these.

---

# 16. Scope

Three weeks.

Must have:

```text
crawler
normalized data
Obsidian
SQLite
Flutter browsing/search
BYOK
chat
retrieval
```

Nice to have:

```text
Firebase
embeddings
chat history
favorites
multiple providers
```

Out of scope:

```text
Neo4j
GraphRAG
multi-agent
microservices
distributed crawler
production backend
```
