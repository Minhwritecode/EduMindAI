# PMDEduMind

Ứng dụng học tập trên **Flutter**, kết hợp **Google Gemini** (gia sư, công cụ theo ngữ cảnh), **Python Flask** (dự đoán phong cách học VARK bằng Random Forest), và tùy chọn **MongoDB** để lưu ghi chú workspace.

**Mã nguồn:** [github.com/Minhwritecode/EduMindAI](https://github.com/Minhwritecode/EduMindAI)

---

## PMDEduMind làm gì

- **Dashboard:** ô **Notebook** — dán tài liệu, outline, câu hỏi; mọi công cụ AI bên dưới đọc nội dung này làm ngữ cảnh.
- **Workspace:** Mindmap, Pomodoro, Quiz, Flashcard, Slide Desk, Report — sinh nội dung phù hợp với Notebook (Gemini).
- **Phân tích lịch:** nhập lịch bận/rảnh và mục tiêu học → gợi ý khung giờ cụ thể (Gemini).
- **Quiz phong cách học (VARK):** 10 câu hỏi → Flask `predictLearningStyle` (Random Forest, dữ liệu `learning_styles.csv`).
- **AI Tutor:** chat với Gemini.
- **Focus Mode & Pomodoro:** đếm thời gian tập trung.
- **Gợi ý nội dung:** danh sách môn / video mẫu trên dashboard (có thể mở rộng thành gợi ý thông minh sau).

---

🚀 Tổng quan
EduAI thích ứng với sở thích học tập của người dùng và tối ưu hóa trải nghiệm học tập của họ bằng cách sử dụng:

Dự đoán phong cách học tập dựa trên học máy
Giải quyết nghi ngờ bằng trí tuệ nhân tạo với GPT-2
Đề xuất khóa học và tài liệu học tập cá nhân hóa
Chế độ tập trung để theo dõi thời gian và phân tích năng suất.

🔬 Mô hình học máy ứng dụng

✅ 1. Công cụ dự đoán phong cách học tập
Mô hình được sử dụng: Bộ phân loại Rừng ngẫu nhiên
Mục tiêu: Phân loại người dùng vào một trong bốn phong cách học tập: Trực quan, Thính giác, Đọc/Viết, Vận động (VARK) .
Bộ dữ liệu: Bộ dữ liệu phản hồi của người dùng với các mẫu hành vi học tập.
Kết quả: Đạt độ chính xác 95% trong phân loại phong cách học tập.

✅ 2. Hệ thống đề xuất thông minh
Mô hình được sử dụng: Mô hình lai (TF-IDF, SVD, Mạng thần kinh)
Mục tiêu: Đề xuất các khóa học và tài liệu học tập dựa trên:
Sở thích môn học
Mức độ khó
Tương tác trong quá khứ
Cách thức triển khai: Kết hợp lọc dựa trên nội dung và lọc cộng tác .

✅ 3. Trợ giảng AI (Giải đáp thắc mắc)
Mô hình được sử dụng: GPT-2 đã được tinh chỉnh (PyTorch)
Mục tiêu: Cung cấp giải đáp thắc mắc tức thì, giải thích và hỗ trợ học tập tương tác .
Dữ liệu huấn luyện: Bộ dữ liệu SQuAD v2 để tinh chỉnh Q&A.
Triển khai:
Tiền xử lý: Mã hóa bằng bộ mã hóa GPT-2.
Tinh chỉnh: Huấn luyện dựa trên PyTorch trên Google Colab .
Suy luận: Được triển khai dưới dạng API chatbot.
Kết quả: Tạo ra các câu trả lời phù hợp với ngữ cảnh .

✅ 4. Chế độ tập trung & Công cụ theo dõi năng suất
Mô hình được sử dụng: Hồi quy Logistic và Phân tích chuỗi thời gian
Mục tiêu: Giúp người dùng theo dõi thời gian học tập tập trung và phân tích xu hướng năng suất .
Triển khai:
Theo dõi thời gian với dữ liệu phiên người dùng
Dự đoán thời gian học tập tối ưu
Phân tích các mô hình tiêu điểm

---
## Công nghệ

| Lớp | Công nghệ |
|-----|-----------|
| App | Flutter (Dart), `provider`, `http`, `flutter_gemini` |
| Backend | Flask, pandas, scikit-learn, pymongo, certifi, flask-cors |
| AI trong app | Google Gemini API |
| ML trên server | Random Forest — phân loại VARK |
| Lưu trữ tùy chọn | MongoDB Atlas (`pm_edu_mind`): `users`, `quiz_results`, `user_tasks`, `notebook_contexts` — qua Flask, app không nhúng URI |

---

## Chạy ứng dụng Flutter

Lần đầu (hoặc sau khi clone), tạo `.env` ở thư mục gốc repo (cùng cấp `pubspec.yaml`) — Flutter bundle file này lúc build:

```bash
cp .env.example .env
# Điền GEMINI_API_KEY=... (và MONGO_URI nếu chỉ chạy Flask)
```

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000 \
  --dart-define=APP_USER_ID=minh
```

- **`GEMINI_API_KEY`:** đặt trong `.env` (khuyến nghị, cùng file với `MONGO_URI` cho Flask). `--dart-define=GEMINI_API_KEY=...` vẫn **ghi đè** `.env` khi cần.
- **Android emulator** trỏ Flask trên máy host: `API_BASE_URL=http://10.0.2.2:5000`
- **Chạy test:** `flutter test`

---

## Chạy backend (Flask)

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
```

Trong `.env` đặt `MONGO_URI=...` nếu dùng đồng bộ Mongo (notebook, hồ sơ, quiz, tasks; xem [MongoDB Atlas](https://www.mongodb.com/docs/atlas/getting-started/)). **Đặt file `.env` cùng thư mục với `app.py`** — Flask luôn nạp biến môi trường từ đó (kể cả khi bạn `cd` sang chỗ khác). Không commit `.env`.

```bash
python app.py
```

**API chính**

| Phương thức | Đường dẫn | Mô tả |
|-------------|-----------|--------|
| `POST` | `/predictLearningStyle` | JSON `Question1` … `Question5` (1–5) → `learningStyle` |
| `GET` | `/health` | `{ "ok", "mongo", "mongo_detail"?, "env_loaded_from"? }` |
| `POST` | `/api/notebook-context` | Lưu `{ "userId", "text" }` |
| `GET` | `/api/notebook-context?userId=...` | Lấy text notebook |
| `GET` / `POST` | `/api/user-profile` | GET `?userId=` — hồ sơ (không có `passwordHash`); POST upsert `{ userId, displayName?, email?, password? }` (mật khẩu hash trên server nếu có) |
| `GET` / `POST` | `/api/quiz-results` | GET `?userId=&quizType=vark&limit=20` — danh sách kết quả mới nhất; POST thêm bản ghi VARK `{ userId, quizType, learningStyle, payload? }` |
| `GET` / `POST` | `/api/tasks` | GET `?userId=` → `{ tasks: [] }`; POST `{ userId, tasks: string[] }` — thay toàn bộ danh sách |

Không có `MONGO_URI` thì các endpoint `/api/*` trên trả **503**; ML VARK vẫn chạy nếu có `learning_styles.csv`.

### MongoDB / SSL (bắt tay TLS) — xử lý sự cố | Troubleshooting

**Nguyên nhân thường gặp:** Python hoặc OpenSSL quá cũ; máy thiếu bundle CA tin cậy; VPN/proxy **SSL inspection** (MITM) làm chứng khác với CA mặc định; Atlas **Network Access** chưa cho phép IP hiện tại.

**Cách xử lý:** Nâng **Python 3.10+**, tạo lại venv, chạy `pip install -U pymongo certifi`. Backend đã dùng **certifi** (`tlsCAFile` trong `app.py`) khi gói cài được. Trên Atlas: thêm IP / `0.0.0.0/0` (chỉ khi chấp nhận rủi ro) vào allowlist. Thử **tắt VPN** hoặc mạng khác để loại trừ proxy chặn TLS.

**Common causes (EN):** old Python/OpenSSL, missing CA bundle, VPN/proxy TLS inspection, Atlas IP not allowlisted. **Fixes:** upgrade Python, recreate venv, `pip install -U pymongo certifi`, rely on certifi in the client (see `app.py`), fix Atlas network access, disable VPN for a quick test.

---

## Cấu trúc thư mục (Dart)

| Đường dẫn | Vai trò |
|-----------|---------|
| `lib/main.dart` | Nạp `.env` (`flutter_dotenv`), khởi tạo Gemini (nếu có key) |
| `lib/const.dart` | `API_BASE_URL`, `APP_USER_ID`; Gemini: `.env` + `--dart-define` (dart-define ưu tiên) |
| `lib/home_page_visual.dart` | Dashboard, Notebook, chip công cụ |
| `lib/notebook_tool_screens.dart` | Mindmap, Quiz notebook, Flashcard, …, Pomodoro |
| `lib/schedule_analyze_page.dart` | Phân tích lịch học |
| `lib/learning_style_page.dart` | Quiz VARK → HTTP Flask |
| `lib/services/notebook_mongo_sync.dart` | Gọi API notebook |
| `lib/services/user_data_sync.dart` | Hồ sơ, quiz VARK, tasks → API Mongo |
| `lib/state/notebook_context_state.dart` | State ngữ cảnh Notebook |

---

## Bảo mật

- Không commit **`.env`**, **API key Gemini**, hay chuỗi **MongoDB** vào Git.
- Nếu `MONGO_URI` hoặc PAT GitHub từng lộ: đổi mật khẩu user DB / thu hồi token trên GitHub.

---

## Ghi chú sản phẩm

- Màn **đăng nhập** gửi hồ sơ lên `/api/user-profile`, đặt `userId` trong app (email chữ thường nếu có, không thì slug từ tên), rồi vào Dashboard.
- **Quiz trong Notebook** (sinh câu hỏi từ nội dung bạn dán) khác **quiz VARK** (gọi Flask); hai luồng độc lập.
