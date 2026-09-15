# FLM Crawl Pipeline

Tài liệu này giải thích cách dự án crawl dữ liệu từ FLM, dữ liệu đi qua những bước nào, dùng thư viện/công cụ gì, và từng loại output được lưu ở đâu.

## 1. Mục tiêu của crawler

Crawler trong dự án này có nhiệm vụ lấy dữ liệu syllabus từ FLM của FPT, giữ lại bản HTML gốc, rồi chuẩn hóa thành dữ liệu có cấu trúc để app có thể tra cứu.

Nguyên tắc quan trọng nhất là:

- Luôn giữ raw HTML gốc.
- Không parse trực tiếp rồi bỏ HTML.
- Nếu parser sai hoặc cần cải thiện, có thể chạy normalize lại từ raw mà không cần crawl lại web.
- Chỉ lấy các syllabus đang active.
- Ghi lại state/report để biết cái nào đã crawl được, cái nào lỗi, cái nào đã xử lý.

Pipeline đầy đủ:

```text
FLM website
  -> discover subject codes
  -> resolve syllabus index by subject code
  -> select active syllabus IDs
  -> fetch syllabus detail HTML
  -> save raw HTML
  -> parse/normalize HTML to JSON
  -> build graph JSONL
  -> export Obsidian Markdown
  -> build SQLite knowledge DB
```

## 2. Crawler dùng gì để crawl?

Code crawler nằm trong thư mục:

```text
crawler/
```

Các thư viện/công cụ chính:

- `requests`: dùng cho một số lệnh crawl đơn giản qua HTTP.
- `Playwright`: dùng để attach vào Chrome đang mở qua Chrome DevTools Protocol (CDP).
- `BeautifulSoup`: parse HTML, đọc bảng, kiểm tra trang có đúng là syllabus detail không.
- `json`: lưu state, index, normalized data, report.
- `sqlite3`: build database local cho app/retrieval.
- `yaml`: tạo frontmatter cho Obsidian note.

Hiện pipeline full crawl chủ yếu dùng Playwright/CDP vì FLM có thể cần session login FEID hoặc browser session hợp lệ.

## 3. Cấu hình crawl

Cấu hình nằm ở:

```text
crawler/src/config.py
```

Các biến chính:

- `FLM_BASE_URL`: base URL của FLM, mặc định là `https://flm.fpt.edu.vn`.
- `CRAWL_DELAY_SECONDS`: delay mặc định giữa request.
- `CRAWL_TIMEOUT_SECONDS`: timeout khi load page/request.
- `CRAWL_MAX_RETRIES`: số lần retry.
- `FLM_PROFILE_DIR`: thư mục profile nếu dùng browser profile riêng.

Khi chạy full crawl bằng CDP, cần Chrome mở với remote debugging, ví dụ:

```bash
google-chrome --remote-debugging-port=9222 --user-data-dir="$HOME/.flm-crawler-chrome"
```

Sau đó login FEID trong Chrome đó. Crawler attach vào browser này để dùng session đã login.

## 4. Entry point chạy crawler

Entry CLI chính:

```text
crawler/main.py
```

Lệnh full crawl thường dùng:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --delay 4 --retries 3
```

Lệnh chỉ normalize từ raw HTML đã có, không mở browser và không fetch lại:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --normalize-only
```

Script full crawl thực tế nằm ở:

```text
crawler/scripts/full_active_crawl.py
```

## 5. Bước 1: Discover subject codes

Mục tiêu: lấy danh sách mã môn học có thể có trên FLM.

Crawler gọi API autocomplete của FLM:

```text
/api/ListSubjectCodeHandler.ashx?term=<prefix>
```

Ví dụ prefix:

```text
A
AI
DB
PR
SW
...
```

Trong full crawl, script dùng nhiều prefix để tránh bị giới hạn số kết quả trả về. Nếu một prefix trả về tới ngưỡng giới hạn, crawler tiếp tục mở rộng prefix sâu hơn.

Kết quả được lưu trong state:

```text
data/crawl_state/full_crawl.json
```

Các key liên quan:

```json
{
  "prefix_queries": {},
  "discovered_subjects": []
}
```

Trong state hiện tại:

```text
discovered_subjects = 2430
```

## 6. Bước 2: Resolve syllabus index

Mục tiêu: với mỗi subject code, vào trang Syllabus Management để lấy các syllabus rows.

URL dạng:

```text
/gui/role/student/SyllabusManagement?searchOn=Code&keyword=<subject_code>
```

Parser đọc bảng:

```text
#gvSyllabus
```

Từ bảng này crawler lấy:

- `syllabus_id`
- `subject_code`
- `subject_name`
- `syllabus_name`
- `is_active`
- `is_approved`
- `decision`
- `detail_url`

Chỉ các dòng có `is_active == true` mới được chọn để fetch detail.

Kết quả được lưu trong:

```text
data/crawl_state/full_crawl.json
```

Các key liên quan:

```json
{
  "subject_results": {},
  "active_syllabi": {}
}
```

Trong state hiện tại:

```text
unique_active_syllabus_ids = 996
```

Nghĩa là crawler đã chọn được 996 syllabus active duy nhất.

## 7. Bước 3: Fetch raw syllabus detail

Mục tiêu: tải trang detail của từng syllabus active.

URL dạng:

```text
/gui/role/student/SyllabusDetails?sylID=<syllabus_id>
```

Trước khi lưu, crawler kiểm tra trang tải về có thật sự là syllabus detail hay không. Trang bị loại nếu:

- bị redirect về login page;
- gặp Cloudflare challenge;
- đang ở Syllabus Management thay vì Syllabus Details;
- không có dấu hiệu của trang detail, ví dụ thiếu heading `Syllabus Details` hoặc thiếu `Syllabus ID:`.

Raw HTML được lưu tại:

```text
data/raw/syllabi/<syllabus_id>.html
```

Ví dụ:

```text
data/raw/syllabi/14350.html
data/raw/syllabi/12035.html
```

Trong state hiện tại:

```text
raw HTML files = 996
valid raw files for selected active IDs = 996
```

Tức là toàn bộ 996 syllabus active đã có raw HTML hợp lệ.

## 8. Vì sao phải giữ raw HTML?

Raw HTML là nguồn dữ liệu gốc từ FLM. Dự án giữ lại raw vì:

- Parser có thể sai hoặc thiếu field.
- Cấu trúc bảng FLM có thể thay đổi.
- Có thể cần normalize lại mà không muốn crawl lại web.
- Có thể audit xem dữ liệu JSON đến từ đâu.
- Nếu app trả lời sai, có thể đối chiếu lại raw HTML.

Mỗi normalized JSON có field:

```json
{
  "source_path": "data/raw/syllabi/<id>.html"
}
```

Field này cho biết JSON được parse từ file raw nào.

## 9. Bước 4: Normalize raw HTML thành JSON

Parser chính nằm ở:

```text
crawler/src/parser/syllabus_parser.py
```

Parser dùng `BeautifulSoup` để đọc tất cả bảng trong HTML, sau đó phân loại bảng theo header.

Các section hiện được parse:

- `general_information`
- `learning_outcomes`
- `assessments`
- `schedule`
- `constructive_questions`
- `materials`

Ví dụ mapping:

- Bảng có header `No. / CLO Name / CLO Details` -> `learning_outcomes`
- Bảng có các cột `Category / Type / Part / Weight / Completion Criteria` -> `assessments`
- Bảng có các cột `Session / Topic / Learning-Teaching Type / LO / ITU` -> `schedule`
- Bảng có `Material Description / Author / Publisher` -> `materials`

Normalized JSON được lưu tại:

```text
data/normalized/syllabi/<syllabus_id>.json
```

Ví dụ:

```text
data/normalized/syllabi/14350.json
```

Trong state/output hiện tại:

```text
normalized JSON files = 996
remaining to normalize = 0
parser failures = 0
```

## 10. Normalize resume hoạt động thế nào?

Hiện full crawl đã được chỉnh để hỗ trợ resume phase normalize an toàn hơn.

Khi chạy:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --normalize-only
```

Crawler sẽ:

- Không attach Chrome.
- Không gọi FLM.
- Không refetch raw HTML.
- Đọc danh sách 996 active syllabus IDs từ `data/crawl_state/full_crawl.json`.
- Kiểm tra file JSON nào đã có trong `data/normalized/syllabi`.
- Chỉ parse các syllabus còn thiếu JSON.
- Lưu JSON ngay sau mỗi syllabus parse thành công.
- Nếu Ctrl+C, ghi lại syllabus đang xử lý rồi thoát sạch.
- Không build graph/Obsidian/SQLite nếu normalize chưa hoàn tất.

Log khi có file cần normalize sẽ có dạng:

```text
[123/996] Normalizing SYL-xxxxx CODE
```

Nếu tất cả JSON đã có, phase normalize sẽ skip hết và chuyển sang build output cuối.

## 11. Chưa chuẩn hóa được thì lưu ở đâu?

Các lỗi normalize/parser được ghi vào:

```text
data/full_crawl/parser_failures.json
```

Các bảng chưa nhận diện được cấu trúc được ghi vào:

```text
data/full_crawl/unknown_table_structures.json
```

Các syllabus bị parse ra `active = false` dù đã đi qua bước chọn active sẽ được ghi vào:

```text
data/full_crawl/inactive_records.json
```

Report tổng hợp nằm ở:

```text
data/full_crawl/full_crawl_report.md
data/full_crawl/full_crawl_report.json
```

Trong lần chạy hiện tại:

```text
parser_failures = 0
unknown_table_structures = 0
active_false_records = 0
```

Nghĩa là không có syllabus nào chưa chuẩn hóa được trong bộ 996 active hiện tại.

## 12. Chỗ ghi crawl thành công/thất bại

State sống của full crawl:

```text
data/crawl_state/full_crawl.json
```

File này là nơi quan trọng nhất để resume.

Các key chính:

```json
{
  "prefix_queries": {},
  "discovered_subjects": [],
  "subject_results": {},
  "active_syllabi": {},
  "detail_results": {},
  "failures": [],
  "blocked_events": [],
  "blocked_at": null,
  "stats": {}
}
```

Ý nghĩa:

- `prefix_queries`: prefix nào đã gọi API autocomplete, status ok/failed, trả về bao nhiêu code.
- `discovered_subjects`: toàn bộ subject code tìm được.
- `subject_results`: kết quả resolve từng subject code trên trang Syllabus Management.
- `active_syllabi`: danh sách syllabus active được chọn để fetch.
- `detail_results`: kết quả fetch từng syllabus detail.
- `failures`: lỗi khi resolve/fetch/normalize.
- `blocked_events`: lịch sử những lần crawler nghi bị login/cloudflare/rate-limit/block.
- `blocked_at`: điểm đang bị block nếu crawl bị dừng vì blocking; có thể là stale nếu sau đó đã fetch lại thành công.
- `stats`: thống kê tổng hợp.

Trong state hiện tại:

```text
detail_results = 996
detail_pages_existing_valid = 5
detail_pages_fetched = 991
detail_pages_failed = 0
blocked_at = null
```

Nghĩa là 5 raw file có sẵn từ trước được reuse, 991 file mới được fetch, tổng cộng đủ 996.

## 13. Bước 5: Build graph JSONL

Sau khi normalize hoàn tất, crawler build graph từ JSON.

Code:

```text
crawler/src/graph/builder.py
```

Output:

```text
data/graph/nodes.jsonl
data/graph/edges.jsonl
```

Graph hiện có node kiểu:

- `Subject`
- `Syllabus`
- `Material`

Edge hiện có:

- `HAS_SYLLABUS`
- `USES_MATERIAL`

Graph chỉ được build sau khi normalize xong.

## 14. Bước 6: Export Obsidian vault

Sau khi normalize hoàn tất, crawler export Markdown để đọc trong Obsidian.

Code:

```text
crawler/src/exporter/obsidian.py
```

Output chính:

```text
vault/Syllabi/SYL-<id>.md
vault/Subjects/<subject_code>.md
vault/Index/Home.md
```

Mỗi syllabus note có frontmatter chứa:

- `id`
- `type`
- `syllabus_id`
- `subject_code`
- `source_path`

Trong body note có:

- Description
- Learning Outcomes
- Assessment
- Schedule
- Constructive Questions
- Materials

## 15. Bước 7: Build SQLite knowledge database

Sau khi normalize hoàn tất, crawler build SQLite DB cho app/retrieval.

Code:

```text
crawler/src/indexer/sqlite_indexer.py
```

Output:

```text
data/knowledge.db
```

Database có các bảng chính:

- `subjects`
- `syllabi`
- `curricula`
- `relations`
- `chunks`
- `chunks_fts`

`chunks_fts` là FTS5 virtual table để search text.

Nội dung syllabus được chia thành chunk theo section:

- `general_information`
- `prerequisite`
- `overview`
- `learning_outcomes`
- `assessment`
- `schedule`
- `constructive_questions`
- `materials`

Schedule được chunk theo từng session, có `session_number`, nên app có thể query kiểu "môn X session 1 học gì".

## 16. Batch validation là gì?

Ngoài full crawl, repo có một pipeline kiểm thử batch nhỏ hơn:

```text
crawler/scripts/controlled_batch_validate.py
```

Output nằm ở:

```text
data/batch_validation/
```

Các thư mục/file chính:

```text
data/batch_validation/raw/syllabi/
data/batch_validation/normalized/syllabi/
data/batch_validation/graph/
data/batch_validation/vault/
data/batch_validation/knowledge.db
data/batch_validation/batch_report.md
data/batch_validation/batch_report.json
```

Batch validation dùng để test parser trên một tập mẫu. Nó có report riêng, không phải output chính cho full crawl.

Kết quả batch hiện tại:

```text
total_attempted = 30
successfully_fetched = 30
successfully_normalized = 30
pass = 28
warn = 2
fail = 0
```

## 17. Output chính hiện tại

Các output chính của full crawl hiện tại:

```text
data/raw/syllabi/                  # 996 raw HTML files
data/normalized/syllabi/           # 996 normalized JSON files
data/graph/nodes.jsonl             # graph nodes
data/graph/edges.jsonl             # graph edges
vault/                             # Obsidian Markdown vault
data/knowledge.db                  # SQLite DB
data/full_crawl/full_crawl_report.md
data/full_crawl/full_crawl_report.json
data/crawl_state/full_crawl.json
```

Full crawl report hiện tại ghi:

```text
Subjects discovered: 2430
Syllabus rows found: 1104
Active syllabus IDs selected: 996
Existing raw reused: 5
New detail pages fetched: 991
Fetch failures: 0
Normalized successfully: 996
Parser failures: 0
Unknown table structures: 0
SQLite syllabi: 996
SQLite chunks: 53834
Schedule sessions: 47752
Schedule chunks: 47752
Consistency PASS
```

## 18. Khi nào nên chạy lệnh nào?

Nếu muốn crawl tiếp từ state hiện tại và có thể fetch web:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --delay 4 --retries 3
```

Nếu chỉ muốn chuẩn hóa lại từ raw HTML đã có, không đụng web:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --normalize-only
```

Nếu vừa Ctrl+C trong lúc normalize:

```bash
.venv/bin/python crawler/main.py full-crawl --resume --normalize-only
```

Nếu parser được sửa và muốn parse lại toàn bộ từ raw, cần xóa hoặc di chuyển các JSON cũ trong:

```text
data/normalized/syllabi/
```

Sau đó chạy lại `--normalize-only`.

## 19. Tóm tắt nơi lưu dữ liệu

| Loại dữ liệu | Đường dẫn |
| --- | --- |
| State/resume full crawl | `data/crawl_state/full_crawl.json` |
| Raw HTML chính | `data/raw/syllabi/<id>.html` |
| Normalized JSON chính | `data/normalized/syllabi/<id>.json` |
| Full crawl report | `data/full_crawl/full_crawl_report.md` |
| Parser failures | `data/full_crawl/parser_failures.json` |
| Unknown table structures | `data/full_crawl/unknown_table_structures.json` |
| Inactive records | `data/full_crawl/inactive_records.json` |
| Graph nodes | `data/graph/nodes.jsonl` |
| Graph edges | `data/graph/edges.jsonl` |
| Obsidian vault | `vault/` |
| SQLite DB | `data/knowledge.db` |
| Batch validation raw | `data/batch_validation/raw/syllabi/` |
| Batch validation normalized | `data/batch_validation/normalized/syllabi/` |
| Batch validation report | `data/batch_validation/batch_report.md` |

## 20. Ghi chú về lỗi blocked/rate-limit

Crawler có logic nhận diện login page, Cloudflare challenge, trang lỗi, hoặc dấu hiệu bị block. Trước đây có thể bị false positive nếu nội dung syllabus có chữ `blocked`.

Logic hiện đã được chỉnh để nếu trang là syllabus detail hợp lệ thì coi là `normal`, không dừng chỉ vì trong nội dung có chữ `blocked`.

Nếu gặp blocking thật, crawler sẽ ghi vào:

```text
data/crawl_state/full_crawl.json
```

Các key:

```json
{
  "blocked_at": {},
  "blocked_events": []
}
```

Sau khi xử lý xong và fetch lại thành công, `blocked_at` stale sẽ được clear.
