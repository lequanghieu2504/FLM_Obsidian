# FLM Knowledge System Operations

File này dành cho người vận hành/dev muốn chạy backend, chạy Flutter app, test hệ thống, và hiểu runtime architecture.

## Architecture

Offline data pipeline đã ổn định:

```text
FLM
→ Python crawler
→ raw HTML
→ normalized JSON
→ knowledge.db
→ graph nodes/edges
→ optional Markdown/Obsidian vault
```

Runtime application:

```text
data/knowledge.db + data/graph/*.jsonl
        ↓
FastAPI backend
        ↓ REST
Flutter Desktop
        ↓
User BYOK LLM
```

Runtime không phụ thuộc vào:

- Obsidian
- Obsidian plugins
- Markdown vault
- FLM crawler
- Re-crawl FLM

## Important Artifacts

- `data/knowledge.db`: SQLite + FTS5 database, read-only runtime knowledge
- `data/graph/nodes.jsonl`: graph nodes
- `data/graph/edges.jsonl`: graph edges
- `backend/`: FastAPI knowledge server
- `app/`: Flutter Desktop client
- `vault/`: optional Obsidian/debug artifact

## Backend Setup

Tạo virtualenv:

```bash
python3 -m venv backend/.venv
```

Cài dependencies:

```bash
backend/.venv/bin/python -m pip install -r backend/requirements.txt
```

Chạy backend development server:

```bash
PYTHONPATH=backend backend/.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

Expected shape:

```json
{
  "status": "ok",
  "knowledge_db": true,
  "graph_nodes": true,
  "graph_edges": true
}
```

## Backend Endpoints

### Health

```http
GET /health
```

### Subjects

```http
GET /api/subjects?q=&page=1&page_size=50
GET /api/subjects/{subject_code}
GET /api/subjects/{subject_code}/schedule
GET /api/subjects/{subject_code}/schedule/{session_number}
```

Subject lookup is case-insensitive.

Examples:

```text
AIS301c
AIS301C
ais301c
```

All should resolve to the same subject when present.

### Search

```http
GET /api/search?q=hiragana
GET /api/search?q=assessment&subject_code=JPD111&section=assessment&limit=8
```

Search uses the SQLite FTS5 index in `data/knowledge.db`.

### Retrieval

```http
POST /api/retrieve
Content-Type: application/json

{
  "query": "JPD111 học hiragana ở buổi nào"
}
```

Backend retrieval does not call an LLM. It only returns relevant chunks.

### Graph

```http
GET /api/graph
GET /api/graph/subject/{subject_code}
GET /api/graph/{entity_id}
```

Graph data is loaded from `data/graph/nodes.jsonl` and `data/graph/edges.jsonl`.

## Flutter Setup

Vào thư mục app:

```bash
cd app
```

Lấy dependencies:

```bash
flutter pub get
```

Chạy app desktop:

```bash
flutter run -d linux
```

Nếu backend không chạy ở `http://localhost:8000`, truyền URL khác:

```bash
flutter run -d linux --dart-define=FLM_BACKEND_URL=http://127.0.0.1:8000
```

Backend URL được cấu hình tập trung tại:

```text
app/lib/core/config/app_config.dart
```

## BYOK LLM Operation

API key được nhập trong màn `Settings` của app.

Rules:

- API key chỉ lưu client-side bằng `flutter_secure_storage`
- Không gửi API key về FastAPI
- Không lưu API key vào `knowledge.db`
- Không lưu API key vào Markdown
- Không commit API key
- Không log API key

LLM flow:

```text
Flutter POST /api/retrieve
→ nhận chunks liên quan
→ dựng grounded prompt
→ gọi OpenAI-compatible API bằng key người dùng
→ hiển thị answer + sources
```

## Validation Commands

Backend compile:

```bash
backend/.venv/bin/python -m compileall backend/app
```

Backend tests:

```bash
PYTHONPATH=backend backend/.venv/bin/python -m pytest backend/tests
```

Flutter format:

```bash
cd app
dart format lib test
```

Flutter analyze:

```bash
cd app
flutter analyze
```

Flutter tests:

```bash
cd app
flutter test
```

Git whitespace check:

```bash
git diff --check
```

## Manual Smoke Tests

Sau khi backend chạy, kiểm tra các flow này trong app:

1. `JPD111 assessment`
2. `JPD111 session 9`
3. `JPD111 học hiragana ở buổi nào`
4. `AIS301C prerequisite`
5. `JPD111 học bao nhiêu tín chỉ`
6. Mở graph `JPD111`
7. Mở detail page `JPD111`

## Do Not Recrawl Unless Needed

Không chạy lại crawler nếu chỉ đang vận hành app.

Không sửa các phần ổn định nếu không bắt buộc:

- `crawler/`
- crawler parser
- active-only crawl policy
- raw HTML
- normalized JSON schema
- full crawl scripts
- existing Obsidian exporter

## Troubleshooting

### Backend không start

Kiểm tra:

- `backend/.venv` đã được tạo chưa
- dependencies đã cài chưa
- `data/knowledge.db` có tồn tại không
- port `8000` có đang bị process khác dùng không

### Flutter không gọi được backend

Kiểm tra:

- Backend server đang chạy
- App đang dùng đúng `FLM_BACKEND_URL`
- Endpoint `/health` trả `status: ok`

### Search không có kết quả

Kiểm tra dữ liệu:

- `data/knowledge.db`
- bảng `chunks`
- virtual table `chunks_fts`

### Graph trống

Kiểm tra:

- `data/graph/nodes.jsonl`
- `data/graph/edges.jsonl`
- endpoint `/api/graph/subject/JPD111`

