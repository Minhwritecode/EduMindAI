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

## Hướng dẫn chạy toàn bộ dự án

Dự án gồm 3 phần chính cần chạy: **Huấn luyện mô hình AI (VARK)**, **Flask Backend**, và **Flutter Frontend (Client)**. Dưới đây là hướng dẫn thiết lập và chạy chi tiết.

### 1. Thiết lập biến môi trường (.env)
Tạo tệp `.env` ở thư mục gốc của dự án (cùng cấp với `pubspec.yaml`):
```bash
cp .env.example .env
```
Mở file `.env` vừa tạo và điền các khóa cần thiết:
- `GEMINI_API_KEY`: Khóa API của Google Gemini (lấy từ Google AI Studio).
- `MONGO_URI`: (Tùy chọn) Chuỗi kết nối MongoDB Atlas nếu bạn muốn lưu trữ dữ liệu trên đám mây. Nếu không điền, hệ thống sẽ tự động chuyển sang cơ sở dữ liệu SQLite cục bộ (`local_db.sqlite`).

---

### 2. Thiết lập và chạy Backend & AI Model (Python)

#### Bước 2.1: Tạo môi trường ảo và cài đặt thư viện phụ thuộc
```bash
python3 -m venv .venv
source .venv/bin/activate   # Trên Windows chạy: .venv\Scripts\activate
pip install -r requirements.txt
pip install pyyaml joblib cython
```
*Lưu ý cho macOS hoặc khi gặp xung đột NumPy:*
Nếu gặp lỗi NumPy 2.x hoặc thiếu thư viện bổ trợ cho Transformers Trainer, hãy cài đặt các phiên bản tương thích sau:
```bash
pip install torch==2.2.1 transformers==4.44.2 "numpy<2" accelerate
```

#### Bước 2.2: Huấn luyện mô hình học tập VARK (PyTorch)
Trước khi chạy backend lần đầu, bạn cần huấn luyện mô hình phân loại phong cách học tập VARK bằng cách chạy script sau:
```bash
python scripts/train_vark_model.py --epochs 2
```
Sau khi hoàn tất, mô hình `learning_style_model.pt` và các cấu hình tokenizer sẽ được lưu ở thư mục gốc để Flask backend load khi khởi động.

#### Bước 2.3: Di chuyển dữ liệu sang SQLite & Huấn luyện mô hình gợi ý Hybrid
Để khởi chạy hệ thống gợi ý khóa học thông minh sử dụng thuật toán Hợp tác lọc lai (Hybrid Collaborative Filtering):
1. **Di chuyển dữ liệu CSV sang SQLite DB (có đánh chỉ mục tối ưu)**:
   ```bash
   python scripts/migrate_csv_to_sqlite.py
   ```
2. **Huấn luyện mô hình Hybrid Recommender**:
   ```bash
   python scripts/train_lightfm.py
   ```
Các file cơ sở dữ liệu `data/recommendations.db` và tệp tin mô hình đã huấn luyện `data/model/lightfm.pkl` sẽ được tạo và nạp tự động bởi Flask backend.

#### Bước 2.4: Khởi động Flask Backend & Trang Quản trị Đề xuất
Chạy server backend trên cổng mặc định `5000`:
```bash
python app.py
```
Server sẽ khởi chạy tại địa chỉ `http://127.0.0.1:5000`.

* **Trang quản trị đề xuất trực quan (Admin Dashboard Panel)**:
  Truy cập địa chỉ: [http://127.0.0.1:5000/admin/recommendations](http://127.0.0.1:5000/admin/recommendations)
  - Đăng nhập Basic Auth bằng tài khoản mặc định: **username**: `admin` / **password**: `admin123` (Cấu hình này có thể thay đổi trong tệp `data/recommendation_config.yaml`).
  - Giao diện cung cấp khả năng điều chỉnh trọng số đề xuất trực quan bằng thanh trượt, re-train mô hình ngay trên web và xem live logs.

#### Bước 2.5: Chạy các kiểm thử (Unit tests) của Backend
Bạn có thể chạy các tệp tin test sử dụng `pytest`:
```bash
PYTHONPATH=. pytest
```

---

### 3. Thiết lập và chạy Frontend (Flutter Client)

#### Bước 3.1: Tải các gói thư viện phụ thuộc của Flutter
```bash
flutter pub get
```

#### Bước 3.2: Chạy ứng dụng Flutter
Khởi chạy ứng dụng bằng lệnh:
```bash
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000 \
  --dart-define=APP_USER_ID=local
```
- **Android Emulator**: Nếu chạy ứng dụng trên máy ảo Android, hãy cấu hình API trỏ về IP loopback của máy chủ host: `--dart-define=API_BASE_URL=http://10.0.2.2:5000`.
- **Chạy kiểm thử (Unit tests)**: `flutter test`

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

---

## Tác giả / Authors

**Copyright (c) 2026 Đinh Trần Tiến Minh | Phan Thanh Phúc | Hoàng Văn Đức**
