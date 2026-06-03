# PMDEduMind (EduMindAI)

EduMindAI is a smart, context-grounded learning ecosystem built with **Flutter**, a **FastAPI** Python backend, **MongoDB** for persistent storage, and the **Google Gemini API** for AI-driven study asset generation.

**Repository:** [github.com/Minhwritecode/EduMindAI](https://github.com/Minhwritecode/EduMindAI)

---

## Features

- **Smart Dashboard:** A centralized, aesthetically-pleasing dark theme dashboard featuring a live clock, dynamic motivational quotes, an overview of your daily timetable, your to-do tasks, and quick access to your most recent notebooks.
- **My Learning (Notebooks):** A persistent workspace to store your notes and documents. This serves as the grounding context for the AI.
- **AI Study Asset Generation:** Inside any notebook, you can leverage Gemini to automatically generate:
  - Mindmaps
  - Quizzes
  - Flashcards
  - Summaries & Reports
- **My Schedule:** A visual timetable grid to manage your weekly classes and activities using an intuitive "Tiết" (Period) system.
- **To-Do List:** Track your upcoming tasks and optionally link them to specific notebooks for quick reference.
- **Focus Mode & Pomodoro:** A built-in Pomodoro timer to help you focus during study sessions.
- **AI Tutor:** Interactive chat with Gemini grounded in your workspace context.

---

## Tech Stack

| Layer | Technologies |
|-------|--------------|
| **Frontend App** | Flutter (Dart), `provider`, `flutter_gemini`, `flutter_dotenv` |
| **Backend Server**| Python, FastAPI, Uvicorn, Motor (Async MongoDB), Google Generative AI |
| **Database** | MongoDB Atlas |
| **AI Models** | Google Gemini (via API) |

---

## Setup Instructions

### 1. Prerequisites
- **Flutter SDK** installed (for running the app).
- **Python 3.8+** installed (for running the FastAPI server).
- A **MongoDB Atlas** cluster URI (or local MongoDB).
- A **Google Gemini API Key** (from Google AI Studio).

### 2. Backend Setup (FastAPI)

1. Navigate to the `server` directory:
   ```bash
   cd server
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file inside the `server` directory and add your credentials:
   ```env
   MONGO_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/?retryWrites=true&w=majority
   GEMINI_API_KEY=your_gemini_api_key_here
   ```
5. Go back to the root directory and run the backend server:
   ```bash
   cd ..
   uvicorn server.main:app --port 5000 --reload
   ```
   *The server will start at `http://127.0.0.1:5000` or `http://localhost:5000`.*

### 3. Frontend Setup (Flutter)

1. Open a new terminal in the root project directory (`EduMindAI`).
2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in the root project directory (`EduMindAI/.env`) for the Flutter app:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   API_BASE_URL=http://127.0.0.1:5000
   ```
   *(Note: If you are running on an Android Emulator, use `http://10.0.2.2:5000` instead of `127.0.0.1`)*
4. Run the Flutter app on a web server:
   ```bash
   flutter run -d web-server
   ```
   *(We recommend running on Web to experience the fixed-height dashboard layout.)*

---

## How to Use the App

1. **Dashboard Navigation**: The app uses a smooth sliding navigation system (`PageView`). Use the bottom navigation bar to slide horizontally between the **Dashboard**, **My Learning**, and **My Schedule** tabs.
2. **Managing Tasks**: On the Dashboard, click the **`+` icon** next to the "To Do List" header to add a new task. You can optionally link this task to an existing notebook. Checking off a task will automatically update the database.
3. **Creating Notes**: Go to **My Learning**, click "New Notebook", and start pasting your study materials or document content.
4. **Generating AI Assets**: While viewing a Notebook, you will see a list of tools at the bottom. Click on "Mindmap", "Quiz", or "Flashcards" to generate study aids strictly based on the text inside that notebook.
5. **Managing Your Timetable**: Go to **My Schedule** to view your weekly grid. Click the **`+` Floating Action Button** to add a new class slot by specifying the day, start period, end period, and subject. Click any existing card on the timetable to update or delete it.
6. **Focusing**: Click the "Pomodoro" floating button on the Dashboard to start a focus timer.

---

## Security Notes
- Never commit your `.env` files to Git.
- Ensure your MongoDB network access allows connections from your current IP or `0.0.0.0/0` if deploying globally.
