# FLM Knowledge User Guide

File này dành cho người dùng cuối muốn dùng ứng dụng Flutter Desktop để tra cứu dữ liệu môn học FLM.

Ứng dụng hiện không cần Obsidian. Obsidian vault chỉ còn là artifact phụ để debug/demo.

## Bạn Cần Gì

- Ứng dụng Flutter Desktop `FLM Knowledge`
- Backend FastAPI đang chạy tại `http://localhost:8000` hoặc URL server do đội vận hành cung cấp
- API key LLM của riêng bạn nếu muốn dùng màn Chat

Bạn không cần:

- Cài Obsidian
- Cài Obsidian plugin
- Mở Markdown vault
- Chạy crawler
- Crawl lại FLM

## Flow Sử Dụng

1. Mở backend knowledge server.

   Nếu bạn chỉ là người dùng cuối, bước này thường do người vận hành làm sẵn.

2. Mở ứng dụng Flutter Desktop.

3. Vào `Subjects` để tìm môn học theo mã hoặc tên.

   Ví dụ:

   - `JPD111`
   - `AIS301c`
   - `PRM393`

4. Bấm vào một môn để xem chi tiết.

   Trang chi tiết có thể hiển thị:

   - Syllabus name
   - Credits
   - Degree level
   - Time allocation
   - Description
   - Prerequisite
   - Learning outcomes
   - Assessment
   - Schedule
   - Materials

5. Vào `Search` để tìm trực tiếp trong knowledge base.

   Ví dụ query:

   - `hiragana`
   - `JPD111 assessment`
   - `AIS301C prerequisite`

6. Vào `Knowledge Graph` để xem quan hệ giữa các node.

   Nhập mã môn, ví dụ `JPD111`, rồi mở graph. Graph hỗ trợ:

   - Pan
   - Zoom
   - Chọn node
   - Mở subject detail nếu node là môn học

7. Vào `Settings` để cấu hình LLM BYOK.

   Cần nhập:

   - Provider: `OpenAI Compatible`
   - Base URL, ví dụ `https://api.openai.com/v1`
   - Model, ví dụ model bạn được cấp quyền dùng
   - API key của bạn

   API key chỉ lưu phía client bằng `flutter_secure_storage`. Backend không nhận, không lưu, không log API key.

8. Vào `Chat` để hỏi đáp có nguồn.

   Flow chat:

   ```text
   Bạn hỏi câu hỏi
   → Flutter gọi POST /api/retrieve
   → Backend trả các chunks liên quan
   → Flutter dựng prompt có context
   → Flutter gọi LLM bằng API key của bạn
   → Ứng dụng hiển thị câu trả lời + sources
   ```

## Câu Hỏi Mẫu

Bạn có thể thử:

- `JPD111 assessment`
- `JPD111 session 9`
- `JPD111 học hiragana ở buổi nào`
- `AIS301C prerequisite`
- `JPD111 học bao nhiêu tín chỉ`

## Cách Đọc Sources Trong Chat

Sau khi hỏi, app sẽ hiện danh sách nguồn bên dưới câu trả lời.

Ví dụ:

```text
JPD111 · schedule · Session 1
JPD111 · schedule · Session 2
JPD111 · schedule · Session 3
JPD111 · schedule · Session 4
```

Nếu context không đủ, LLM được yêu cầu trả lời rằng FLM knowledge base không cung cấp đủ thông tin.

## Lỗi Thường Gặp

### Không tải được Subjects/Search/Graph

Backend có thể chưa chạy hoặc URL backend sai.

Mặc định app gọi:

```text
http://localhost:8000
```

### Chat báo chưa cấu hình LLM

Vào `Settings` và kiểm tra:

- Base URL
- Model
- API key

### Chat trả lời không đủ thông tin

Điều này có nghĩa backend retrieve không tìm được chunk phù hợp, hoặc dữ liệu FLM hiện có không chứa phần đó.

