# PMDEduMind (EduMindAI)

EduMindAI is a smart, context-grounded learning ecosystem built with **Flutter** (Frontend), and a hybrid Python backend structure containing both **FastAPI** (for authentication, chat, and notebook management) and **Flask** (for the AI/ML Recommendation Engine, VARK Classifier, and Admin Panel).

**Repository:** [github.com/Minhwritecode/EduMindAI](https://github.com/Minhwritecode/EduMindAI)

---

## Features

- **Smart Personalized Dashboard:** A centralized, aesthetically-pleasing dark theme dashboard featuring a live clock, dynamic motivational quotes, daily schedule, to-do list, and **personalized course recommendations** powered by a trained Hybrid Recommendation model.
- **My Learning (Notebooks):** A persistent workspace to store your notes and documents, synced with MongoDB.
- **AI Study Asset Generation:** Inside any notebook, generate context-grounded Mindmaps, Quizzes, Flashcards, and reports using Gemini.
- **My Schedule:** A visual timetable grid to manage your weekly classes and activities using an intuitive "Tiết" (Period) system.
- **To-Do List:** Track your upcoming tasks, check off completed ones, and link them to notebooks.
- **Focus Mode & Pomodoro:** A built-in focus timer on the Dashboard to help you concentrate.
- **Learning Style Assessment (VARK):** Assess your style (Visual, Auditory, Reading/Writing, Kinesthetic) to personalize recommendations.

---

## Tech Stack (Hybrid Coexistence Architecture)

| Layer | Component | Technologies | Port / Configuration |
|-------|-----------|--------------|----------------------|
| **Frontend** | Flutter Client | Flutter (Dart), `provider`, `http`, `flutter_gemini`, `flutter_dotenv` | Runs locally, connects to Ports 5000 & 8000 |
| **Backend 1** | FastAPI Server | Python, FastAPI, MongoDB (Motor), Gemini API, Uvicorn | Runs on **Port 8000** (Auth, Chat, Notebooks, Schedule) |
| **Backend 2** | Flask Server | Python, Flask, SQLite, Pandas, Scikit-learn, LightFM | Runs on **Port 5000** (VARK classifier, Hybrid Recommender, Admin Panel) |
| **Databases**| Storage Layer | MongoDB Atlas (FastAPI) & Indexed SQLite DB (Flask Recommender) | `pm_edu_mind` & `data/recommendations.db` |

---

## Setup Instructions

### 1. Prerequisites
- **Flutter SDK** installed (for running the app).
- **Python 3.9+** installed (with `python3 -m venv` support).
- A **MongoDB Atlas** cluster URI.
- A **Google Gemini API Key** (from Google AI Studio).

### 2. Environment Variables (.env)
Create a `.env` file in the root project directory (`EduMindAI/.env`):
```env
GEMINI_API_KEY=your_gemini_api_key_here
API_BASE_URL=http://127.0.0.1:5000
FASTAPI_BASE_URL=http://127.0.0.1:8000
```
*(Note: If you run on Android Emulator, use `http://10.0.2.2:5000` and `http://10.0.2.2:8000`)*

For the FastAPI server, create a `.env` inside the `server/` folder:
```env
MONGO_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/pm_edu_mind
GEMINI_API_KEY=your_gemini_api_key_here
```

---

### 3. Backend Setup & AI Model Training (Python)

#### Step 3.1: Create Virtual Environment and Install Dependencies
In the root directory, set up your Python virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
pip install pyyaml joblib cython
```

#### Step 3.2: Train the VARK classifier
Train the VARK learning style classifier:
```bash
python scripts/train_vark_model.py --epochs 2
```
This saves `learning_style_model.pt` in the project root.

#### Step 3.3: Database Migration & Recommendation Model Training
1. **Migrate CSV data to SQLite** (for the collaborative/hybrid recommendation system):
   ```bash
   python scripts/migrate_csv_to_sqlite.py
   ```
2. **Train the Hybrid Recommender model**:
   ```bash
   python scripts/train_lightfm.py
   ```
This generates the database `data/recommendations.db` and the model `data/model/lightfm.pkl`.

#### Step 3.4: Running both Servers
Keep both terminals open:
- **Terminal 1: Start FastAPI Backend (Port 8000)**
  ```bash
  source .venv/bin/activate
  uvicorn server.main:app --port 8000 --reload
  ```
- **Terminal 2: Start Flask Recommender & Admin Backend (Port 5000)**
  ```bash
  source .venv/bin/activate
  python app.py
  ```

#### Step 3.5: Access the Recommendation Admin Panel
Go to [http://127.0.0.1:5000/admin/recommendations](http://127.0.0.1:5000/admin/recommendations):
- Login: **username**: `admin` / **password**: `admin123` (configured in `data/recommendation_config.yaml`).
- Features: Adjust recommendation weights live, trigger on-demand model retraining, and view system logs.

#### Step 3.6: Run Tests
To run unit and integration tests:
```bash
PYTHONPATH=. pytest
```

---

### 4. Frontend Setup & Run (Flutter)

1. Fetch dependencies:
   ```bash
   flutter pub get
   ```
2. Run the application:
   ```bash
   flutter run
   ```
   *(We recommend running on Desktop/Web to experience the full-width side-by-side dashboard layout.)*

---

## Security Notes
- Do not commit your `.env` files.
- Ensure your MongoDB network access allows connections from your current IP or `0.0.0.0/0`.
- All model weights, SQLite paths, and pagination settings can be customized in `data/recommendation_config.yaml`.

---

## Authors / Copyright
**Copyright (c) 2026 Đinh Trần Tiến Minh | Phan Thanh Phúc | Hoàng Văn Đức**
