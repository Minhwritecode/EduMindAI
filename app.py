import os
from datetime import datetime, timezone
from typing import Optional

from flask import Flask, request, jsonify
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

# Always load .env from the same directory as this file (avoids 503 when cwd ≠ project root).
_ROOT = os.path.dirname(os.path.abspath(__file__))
_ENV_PATH = os.path.join(_ROOT, ".env")
try:
    from dotenv import load_dotenv

    load_dotenv(_ENV_PATH)
    load_dotenv()  # fallback: current working directory
except ImportError:
    pass

try:
    from flask_cors import CORS
except ImportError:
    CORS = None  # type: ignore

try:
    from pymongo import MongoClient
except ImportError:
    MongoClient = None  # type: ignore

try:
    import certifi
except ImportError:
    certifi = None  # type: ignore

try:
    from werkzeug.security import generate_password_hash
except ImportError:
    generate_password_hash = None  # type: ignore

app = Flask(__name__)
if CORS is not None:
    CORS(app)

mongo_uri = os.environ.get("MONGO_URI", "").strip()
mongo_db = None
mongo_last_error: Optional[str] = None

if not mongo_uri:
    mongo_last_error = (
        "MONGO_URI is empty. Add it to .env in the project folder (same folder as app.py), "
        "then restart Flask."
    )
elif MongoClient is None:
    mongo_last_error = "pymongo is not installed (pip install pymongo)."
else:
    try:
        if certifi is not None:
            _client = MongoClient(
                mongo_uri,
                serverSelectionTimeoutMS=8000,
                tlsCAFile=certifi.where(),
            )
        else:
            _client = MongoClient(mongo_uri, serverSelectionTimeoutMS=8000)
        mongo_db = _client["pm_edu_mind"]
        mongo_db.command("ping")
    except Exception as exc:  # noqa: BLE001
        mongo_last_error = str(exc)
        print("MongoDB connection failed:", exc)
        mongo_db = None


def _mongo_unavailable():
    body = {
        "ok": False,
        "error": mongo_last_error or "MongoDB is not available.",
        "hint": "Put MONGO_URI in .env next to app.py, verify Atlas Network Access and TLS, then restart: python app.py",
    }
    return jsonify(body), 503


# Load the dataset
df = pd.read_csv('learning_styles.csv')

# Preprocess data and train the model (replace with your model training logic)
X = df.drop('LearningStyle', axis=1)
y = df['LearningStyle']

model = RandomForestClassifier()
model.fit(X, y)

@app.route('/predictLearningStyle', methods=['POST'])
def predict_learning_style():
    data = request.get_json()

    # Example data received from Flutter app
    question_data = pd.DataFrame(data, index=[0])

    # Make prediction
    prediction = model.predict(question_data)

    # Respond with predicted learning style
    return jsonify({'learningStyle': prediction[0]})


@app.route("/health", methods=["GET"])
def health():
    detail = None
    if mongo_db is None and mongo_last_error:
        detail = mongo_last_error[:400]
    return jsonify(
        {
            "ok": True,
            "mongo": mongo_db is not None,
            "mongo_detail": detail,
            "env_loaded_from": _ENV_PATH if os.path.isfile(_ENV_PATH) else None,
        }
    )


@app.route("/api/notebook-context", methods=["POST"])
def save_notebook_context():
    """Upsert notebook text for a user (Flutter Notebook panel)."""
    if mongo_db is None:
        return _mongo_unavailable()
    data = request.get_json(silent=True) or {}
    user_id = str(data.get("userId", "local"))
    text = str(data.get("text", ""))
    mongo_db["notebook_contexts"].update_one(
        {"userId": user_id},
        {
            "$set": {
                "userId": user_id,
                "text": text,
                "updatedAt": datetime.now(timezone.utc),
            }
        },
        upsert=True,
    )
    return jsonify({"ok": True}), 200


@app.route("/api/notebook-context", methods=["GET"])
def get_notebook_context():
    if mongo_db is None:
        return _mongo_unavailable()
    user_id = request.args.get("userId", "local")
    doc = mongo_db["notebook_contexts"].find_one(
        {"userId": user_id}, projection={"_id": 0, "text": 1}
    )
    text = (doc or {}).get("text", "")
    return jsonify({"ok": True, "text": text}), 200


@app.route("/api/user-profile", methods=["GET", "POST"])
def user_profile():
    if mongo_db is None:
        return _mongo_unavailable()
    if request.method == "GET":
        user_id = str(request.args.get("userId", "")).strip()
        if not user_id:
            return jsonify({"ok": False, "error": "userId query parameter required"}), 400
        doc = mongo_db["users"].find_one(
            {"userId": user_id},
            projection={"_id": 0, "passwordHash": 0},
        )
        if not doc:
            return (
                jsonify(
                    {
                        "ok": True,
                        "userId": user_id,
                        "displayName": "",
                        "email": "",
                    }
                ),
                200,
            )
        return (
            jsonify(
                {
                    "ok": True,
                    "userId": doc.get("userId", user_id),
                    "displayName": doc.get("displayName", "") or "",
                    "email": doc.get("email", "") or "",
                }
            ),
            200,
        )

    data = request.get_json(silent=True) or {}
    user_id = str(data.get("userId", "")).strip()
    if not user_id:
        return jsonify({"ok": False, "error": "userId required in JSON body"}), 400

    set_doc: dict = {"userId": user_id, "updatedAt": datetime.now(timezone.utc)}
    if "displayName" in data and data["displayName"] is not None:
        set_doc["displayName"] = str(data["displayName"]).strip()
    if "email" in data and data["email"] is not None:
        set_doc["email"] = str(data["email"]).strip()

    pwd = data.get("password")
    if pwd is not None and str(pwd).strip():
        if generate_password_hash is None:
            return (
                jsonify(
                    {
                        "ok": False,
                        "error": "werkzeug.security not available; cannot hash password",
                    }
                ),
                500,
            )
        set_doc["passwordHash"] = generate_password_hash(str(pwd))

    mongo_db["users"].update_one(
        {"userId": user_id},
        {"$set": set_doc},
        upsert=True,
    )
    return jsonify({"ok": True}), 200


@app.route("/api/quiz-results", methods=["GET", "POST"])
def quiz_results():
    if mongo_db is None:
        return _mongo_unavailable()

    if request.method == "GET":
        user_id = str(request.args.get("userId", "")).strip()
        if not user_id:
            return jsonify({"ok": False, "error": "userId query parameter required"}), 400
        quiz_type = str(request.args.get("quizType", "vark")).strip() or "vark"
        try:
            limit = int(request.args.get("limit", "20"))
        except ValueError:
            limit = 20
        limit = max(1, min(limit, 50))

        cursor = mongo_db["quiz_results"].find(
            {"userId": user_id, "quizType": quiz_type},
            projection={"_id": 0},
            sort=[("createdAt", -1)],
            limit=limit,
        )
        results = []
        for doc in cursor:
            row = dict(doc)
            ca = row.get("createdAt")
            if hasattr(ca, "isoformat"):
                row["createdAt"] = ca.isoformat()
            results.append(row)
        return jsonify({"ok": True, "results": results}), 200

    data = request.get_json(silent=True) or {}
    user_id = str(data.get("userId", "")).strip()
    if not user_id:
        return jsonify({"ok": False, "error": "userId required"}), 400
    quiz_type = str(data.get("quizType", "vark")).strip() or "vark"
    learning_style = str(data.get("learningStyle", "")).strip()
    if not learning_style:
        return jsonify({"ok": False, "error": "learningStyle required"}), 400
    payload = data.get("payload")
    if payload is not None and not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "payload must be an object if present"}), 400

    created = datetime.now(timezone.utc)
    doc = {
        "userId": user_id,
        "quizType": quiz_type,
        "learningStyle": learning_style,
        "createdAt": created,
    }
    if isinstance(payload, dict):
        doc["payload"] = payload

    mongo_db["quiz_results"].insert_one(doc)
    return jsonify({"ok": True, "createdAt": created.isoformat()}), 200


@app.route("/api/tasks", methods=["GET", "POST"])
def user_tasks():
    if mongo_db is None:
        return _mongo_unavailable()

    if request.method == "GET":
        user_id = str(request.args.get("userId", "")).strip()
        if not user_id:
            return jsonify({"ok": False, "error": "userId query parameter required"}), 400
        doc = mongo_db["user_tasks"].find_one(
            {"userId": user_id},
            projection={"_id": 0, "tasks": 1},
        )
        tasks = (doc or {}).get("tasks") or []
        if not isinstance(tasks, list):
            tasks = []
        tasks = [str(t) for t in tasks]
        return jsonify({"ok": True, "tasks": tasks}), 200

    data = request.get_json(silent=True) or {}
    user_id = str(data.get("userId", "")).strip()
    if not user_id:
        return jsonify({"ok": False, "error": "userId required"}), 400
    raw_tasks = data.get("tasks")
    if not isinstance(raw_tasks, list):
        return jsonify({"ok": False, "error": "tasks must be an array of strings"}), 400
    tasks = [str(t) for t in raw_tasks]

    mongo_db["user_tasks"].update_one(
        {"userId": user_id},
        {
            "$set": {
                "userId": user_id,
                "tasks": tasks,
                "updatedAt": datetime.now(timezone.utc),
            }
        },
        upsert=True,
    )
    return jsonify({"ok": True}), 200


if __name__ == '__main__':
    app.run(debug=True)
