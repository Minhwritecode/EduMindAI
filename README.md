# PMDEduMind

**PMDEduMind** là ứng dụng học thông minh (Flutter + Python Flask), kế thừa hướng **EduAI / smart learning** và **bổ sung** workspace kiểu **NotebookLM** để bạn dán tài liệu, dùng AI trên chính ngữ cảnh đó, và đồng bộ ghi chú qua **MongoDB** (tùy chọn).

**Repository:** [github.com/Minhwritecode/EduMindAI](https://github.com/Minhwritecode/EduMindAI)

---

## Bảo mật (quan trọng)

- **Không** dán chuỗi `MONGO_URI` hay mật khẩu database vào chat công khai, issue, hay commit Git. Hãy đặt chỉ trong file **`.env`** (đã có trong `.gitignore`). Nếu URI đã lộ, vào **MongoDB Atlas → Database Access** đổi mật khẩu user và cập nhật lại `.env`.
- **Gemini:** dùng `--dart-define=GEMINI_API_KEY=...` khi build/run; không commit key.

---

## Tầm nhìn sản phẩm (mô tả kế thừa EduAI)

Phần dưới giữ **nội dung ý tưởng / roadmap** của dự án gốc; một số mục là **hướng nghiên cứu hoặc mô tả mô hình**, không nhất thiết đã triển khai đầy đủ trong code hiện tại — phần **“Trong code hiện tại”** bên dưới ghi rõ thực tế.

**PMDEduMind** là người đồng hành học tập, kết hợp **ML** và **DL**, nhằm cá nhân hóa trải nghiệm, gia sư AI, và theo dõi năng suất.

| | |
|--|--|
| **Loại dự án** | Ứng dụng học tập có AI/ML |
| **Trạng thái** | Đang phát triển |
| **Tech stack (mục tiêu / tổng thể)** | Flutter, Python (Flask, Pandas, Sklearn), có thể mở rộng TensorFlow; lưu trữ có thể qua **MongoDB** (Flask API) |

### Overview (EduAI vision)

Ứng dụng thích ứng **phong cách học** và tối ưu lịch học với:

- **ML — Learning style prediction** (Random Forest / VARK trong pipeline gốc).
- **AI — gỡ rối / ôn tập** (trong bản hiện tại: **Google Gemini** cho chat và công cụ Notebook).
- **Gợi ý khóa học / tài liệu** (một phần là UI demo + dữ liệu tĩnh; có thể nối thêm model gợi ý).
- **Focus / Pomodoro** — theo dõi thời gian tập trung.

### Các mô hình / hướng ML (mô tả dự án gốc)

1. **Learning Style Predictor** — Random Forest, phân loại VARK; dataset hành vi học; báo cáo gốc ~95% accuracy trên tập huấn luyện.
2. **Smart Recommendation** — hướng hybrid (TF-IDF, SVD, NN), gợi ý theo môn / độ khó / tương tác.
3. **AI Tutor** — mô tả gốc: GPT-2 fine-tune SQuAD; **bản PMDEduMind hiện tại** dùng **Gemini** qua `flutter_gemini`, không phải GPT-2 trong app.
4. **Focus & productivity** — mô tả gốc: logistic regression / chuỗi thời gian; **trong app** có Focus timer + Pomodoro; phân tích xu hướng nâng cao có thể bổ sung sau.

### Experiment tracking (tham chiếu tài liệu gốc)

| Model | Accuracy (ghi chú gốc) | Dataset | Ghi chú |
|--------|------------------------|---------|--------|
| Learning style | ~95% (tập huấn luyện) | learning_styles.csv | Endpoint Flask `POST /predictLearningStyle` |
| Recommendation | — | Course interactions | Roadmap |
| AI Tutor (Gemini) | — | Ngữ cảnh người dùng | Đang dùng Gemini API |

---

## NotebookLM-style (bổ sung — tối ưu trải nghiệm)

Đây là **lớp công cụ thêm** trên nền tảng app, không thay thế các mục EduAI phía trên:

- **Dashboard — Notebook:** ô nhập **nguồn / ghi chú** dùng chung cho prompt AI.
- **Công cụ:** Mindmap, Pomodoro, Quiz, Flashcard, Slide Desk, Report (Gemini đọc nội dung Notebook).
- **Phân tích lịch:** nhập lịch rảnh/bận + mục tiêu → Gemini gợi ý khung giờ học.
- **Đồng bộ MongoDB:** nút upload/download → Flask `POST/GET /api/notebook-context` (cần `MONGO_URI` trong `.env` trên máy chạy Flask).

---

## Trong code hiện tại (đã nối / đã đổi)

| Hạng mục | Trạng thái |
|----------|------------|
| Quiz phong cách học → **Flask `app.py`** | **Đã nối:** `POST /predictLearningStyle`, gửi `Question1`…`Question5` (gộp từ 10 câu UI). Cần chạy `python app.py` và đúng `API_BASE_URL`. |
| **Gemini** | **Đã chuyển sang** `--dart-define=GEMINI_API_KEY=...` (không còn hardcode trong `lib/const.dart`). |
| **Android `applicationId`** | **Đã đổi** thành `com.minhwritecode.pm_edumind` + `MainActivity` package tương ứng; `android:label` = **PMDEduMind**. |
| MongoDB | Flask đọc `MONGO_URI` từ `.env`; app Flutter gọi HTTP (không nhúng URI vào app). |

---

## Chạy Flutter

```bash
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000 \
  --dart-define=APP_USER_ID=minh
```

- **Android emulator** gọi Flask trên máy host: `API_BASE_URL=http://10.0.2.2:5000`
- **Test:** `flutter test` không cần Gemini cho màn splash; nếu thêm test gọi AI thì truyền `--dart-define=GEMINI_API_KEY=...`.

---

## Chạy backend + MongoDB

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Trong .env: MONGO_URI=mongodb+srv://...  (chỉ trên máy bạn, không commit)
python app.py
```

- `GET /health` — kiểm tra Flask và cờ `mongo`.
- Không có `MONGO_URI` → API notebook trả **503**; quiz ML vẫn chạy nếu có `learning_styles.csv`.

Hướng dẫn Atlas: [MongoDB Atlas Getting Started](https://www.mongodb.com/docs/atlas/getting-started/).

---

## Cấu trúc Dart chính

| File | Vai trò |
|------|---------|
| `lib/learning_style_page.dart` | Quiz 10 câu → HTTP → Flask |
| `lib/state/notebook_context_state.dart` | Ngữ cảnh Notebook |
| `lib/home_page_visual.dart` | Dashboard + Notebook + chip công cụ |
| `lib/notebook_tool_screens.dart` | Mindmap / Quiz / … + Pomodoro |
| `lib/schedule_analyze_page.dart` | Phân tích lịch (Gemini) |
| `lib/services/notebook_mongo_sync.dart` | Đồng bộ notebook |

---

## Ghi chú

- Đăng nhập hiện là **demo** (LOGIN → Dashboard).
- **Notebook Quiz** (sinh đề từ Notebook) khác **Quiz VARK** (nối Flask); cả hai đều có trong app.
