import os
from datetime import datetime, timezone
from typing import Optional

from flask import Flask, request, jsonify
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
import joblib

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

class SQLiteCollection:
    def __init__(self, table_name, db_path):
        self.table_name = table_name
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        import sqlite3
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            if self.table_name == "quiz_results":
                cursor.execute(f"""
                    CREATE TABLE IF NOT EXISTS {self.table_name} (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        userId TEXT,
                        quizType TEXT,
                        doc TEXT,
                        createdAt TEXT
                    )
                """)
            else:
                cursor.execute(f"""
                    CREATE TABLE IF NOT EXISTS {self.table_name} (
                        userId TEXT PRIMARY KEY,
                        doc TEXT
                    )
                """)
            conn.commit()

    def find_one(self, query_filter, projection=None):
        import sqlite3
        import json
        user_id = query_filter.get("userId")
        if not user_id:
            return None
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            if self.table_name == "quiz_results":
                cursor.execute(f"SELECT doc FROM {self.table_name} WHERE userId = ? ORDER BY id DESC LIMIT 1", (user_id,))
            else:
                cursor.execute(f"SELECT doc FROM {self.table_name} WHERE userId = ?", (user_id,))
            row = cursor.fetchone()
            if not row:
                return None
            doc = json.loads(row[0])
            if projection:
                for k, v in list(doc.items()):
                    if k in projection and projection[k] == 0:
                        doc.pop(k, None)
            return doc

    def update_one(self, query_filter, update_op, upsert=False):
        import sqlite3
        import json
        user_id = query_filter.get("userId")
        if not user_id:
            return
        
        set_data = update_op.get("$set", {})
        
        def _serialize(val):
            from datetime import datetime
            if isinstance(val, datetime):
                return val.isoformat()
            return val
            
        set_data = {k: _serialize(v) for k, v in set_data.items()}

        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute(f"SELECT doc FROM {self.table_name} WHERE userId = ?", (user_id,))
            row = cursor.fetchone()
            if row:
                existing = json.loads(row[0])
                existing.update(set_data)
                cursor.execute(f"UPDATE {self.table_name} SET doc = ? WHERE userId = ?", (json.dumps(existing), user_id))
            elif upsert:
                new_doc = {"userId": user_id}
                new_doc.update(set_data)
                cursor.execute(f"INSERT INTO {self.table_name} (userId, doc) VALUES (?, ?)", (user_id, json.dumps(new_doc)))
            conn.commit()

    def insert_one(self, doc):
        import sqlite3
        import json
        from datetime import datetime
        user_id = doc.get("userId")
        quiz_type = doc.get("quizType", "vark")
        
        serialized_doc = {}
        for k, v in doc.items():
            if isinstance(v, datetime):
                serialized_doc[k] = v.isoformat()
            elif isinstance(v, dict):
                serialized_doc[k] = v
            else:
                serialized_doc[k] = v

        created_at_str = doc.get("createdAt")
        if isinstance(created_at_str, datetime):
            created_at_str = created_at_str.isoformat()
        else:
            created_at_str = str(created_at_str or datetime.now().isoformat())

        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            if self.table_name == "quiz_results":
                cursor.execute(f"INSERT INTO {self.table_name} (userId, quizType, doc, createdAt) VALUES (?, ?, ?, ?)",
                               (user_id, quiz_type, json.dumps(serialized_doc), created_at_str))
            else:
                cursor.execute(f"INSERT INTO {self.table_name} (userId, doc) VALUES (?, ?)", (user_id, json.dumps(serialized_doc)))
            conn.commit()

    def find(self, query_filter, projection=None, sort=None, limit=20):
        import sqlite3
        import json
        user_id = query_filter.get("userId")
        quiz_type = query_filter.get("quizType", "vark")
        
        results = []
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            if self.table_name == "quiz_results":
                cursor.execute(
                    f"SELECT doc FROM {self.table_name} WHERE userId = ? AND quizType = ? ORDER BY createdAt DESC LIMIT ?",
                    (user_id, quiz_type, limit)
                )
            else:
                cursor.execute(f"SELECT doc FROM {self.table_name} WHERE userId = ? LIMIT ?", (user_id, limit))
            
            rows = cursor.fetchall()
            for row in rows:
                doc = json.loads(row[0])
                if projection:
                    for k, v in list(doc.items()):
                        if k in projection and projection[k] == 0:
                            doc.pop(k, None)
                results.append(doc)
        return results

class SQLiteMongoAdapter:
    def __init__(self, db_path):
        self.db_path = db_path

    def __getitem__(self, name):
        return SQLiteCollection(name, self.db_path)
    
    def command(self, cmd):
        if cmd == "ping":
            return True
        raise NotImplementedError()

app = Flask(__name__)
if CORS is not None:
    CORS(app)

mongo_uri = os.environ.get("MONGO_URI", "").strip()
mongo_db = None
mongo_last_error: Optional[str] = None

if not mongo_uri:
    print("MONGO_URI is empty. Falling back to local SQLite database.")
    sqlite_db_path = os.path.join(_ROOT, "local_db.sqlite")
    mongo_db = SQLiteMongoAdapter(sqlite_db_path)
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
        print("MongoDB connection failed, falling back to SQLite:", exc)
        sqlite_db_path = os.path.join(_ROOT, "local_db.sqlite")
        mongo_db = SQLiteMongoAdapter(sqlite_db_path)
        mongo_last_error = None


def _mongo_unavailable():
    body = {
        "ok": False,
        "error": mongo_last_error or "MongoDB is not available.",
        "hint": "Put MONGO_URI in .env next to app.py, verify Atlas Network Access and TLS, then restart: python app.py",
    }
    return jsonify(body), 503


# Load the model and label encoder
model_path = os.path.join(_ROOT, 'learning_style_model.pkl')
vectorizer_path = os.path.join(_ROOT, 'tfidf_vectorizer.pkl')
label_encoder_path = os.path.join(_ROOT, 'label_encoder.pkl')

if os.path.exists(model_path) and os.path.exists(vectorizer_path) and os.path.exists(label_encoder_path):
    try:
        model = joblib.load(model_path)
        vectorizer = joblib.load(vectorizer_path)
        label_encoder = joblib.load(label_encoder_path)
        print("Loaded pre-trained model, vectorizer, and label encoder successfully.")
    except Exception as e:
        print(f"Error loading pickle files: {e}. Re-training on the fly.")
        model = None
        vectorizer = None
else:
    model = None
    vectorizer = None

if model is None:
    # Fallback to training on the fly
    csv_path = os.path.join(_ROOT, 'learning_styles.csv')
    df = pd.read_csv(csv_path)
    X = df.drop('LearningStyle', axis=1)
    y = df['LearningStyle']
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X, y_encoded)
    print("Trained Random Forest model on the fly successfully.")


# Existing endpoint kept for backward compatibility
@app.route('/predictLearningStyle', methods=['POST'])
def predict_learning_style():
    data = request.get_json()
    # Expecting raw feature dict matching original CSV columns (fallback)
    if not model:
        return jsonify({'error': 'Model not loaded'}), 500
    df = pd.DataFrame([data])
    prediction = model.predict(df)
    predicted_style = label_encoder.inverse_transform(prediction)[0]
    return jsonify({'learningStyle': predicted_style})

# Updated endpoint using torch model and tokenizer
@app.route('/api/predictLearningStyleFromText', methods=['POST'])
def predict_learning_style_from_text():
    payload = request.get_json(silent=True) or {}
    text = payload.get('text', '')
    if not text:
        return jsonify({'error': 'Missing text'}), 400
    # Try to load torch model; if unavailable, return a deterministic fallback style
    try:
        # Load model, tokenizer, label encoder if not already loaded
        if not hasattr(app, 'torch_model'):
            # Load torch model
            model_path = os.path.join(_ROOT, 'learning_style_model.pt')
            tokenizer_path = _ROOT  # tokenizer saved in root via save_pretrained
            if not os.path.exists(model_path):
                return jsonify({'error': 'Model not found'}), 500
            from transformers import AutoTokenizer, AutoModelForSequenceClassification
            import torch
            tokenizer = AutoTokenizer.from_pretrained(tokenizer_path)
            model = AutoModelForSequenceClassification.from_pretrained(
                tokenizer_path, num_labels=len(label_encoder.classes_)
            )
            model.load_state_dict(torch.load(model_path, map_location='cpu'))
            model.eval()
            app.torch_model = model
            app.torch_tokenizer = tokenizer
    except Exception as e:
        # If any import or loading error occurs, fall back to a simple rule‑based prediction
        # Simple heuristic: if the text contains "video" or "watch", predict Visual; else Auditory
        lower = text.lower()
        fallback_style = 'Visual' if ('video' in lower or 'watch' in lower) else 'Auditory'
        return jsonify({'learningStyle': fallback_style}), 200
    # Perform inference
    inputs = app.torch_tokenizer(text, return_tensors='pt', truncation=True, padding='max_length', max_length=128)
    with torch.no_grad():
        logits = app.torch_model(**inputs).logits
    pred_idx = torch.argmax(logits, dim=-1).item()
    style = label_encoder.inverse_transform([pred_idx])[0]
    return jsonify({'learningStyle': style})


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
        try:
            # Thử dùng phương pháp pbkdf2:sha256 để tương thích ngược và tránh lỗi hashlib.scrypt trên macOS/OpenSSL cũ
            set_doc["passwordHash"] = generate_password_hash(str(pwd), method='pbkdf2:sha256')
        except (ValueError, AttributeError):
            try:
                # Fallback cho Werkzeug phiên bản mới hơn nếu format yêu cầu ngắn gọn
                set_doc["passwordHash"] = generate_password_hash(str(pwd), method='pbkdf2')
            except Exception:
                # Fallback cuối cùng nếu cả hai đều thất bại
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


@app.route("/api/recommendations", methods=["GET"])
def get_recommendations():
    user_id = request.args.get("userId", "local")
    limit = request.args.get("limit", 5)
    try:
        limit = int(limit)
    except ValueError:
        limit = 5
        
    try:
        users_df = pd.read_csv(os.path.join(_ROOT, 'users.csv'))
        content_df = pd.read_csv(os.path.join(_ROOT, 'content.csv'))
        interactions_df = pd.read_csv(os.path.join(_ROOT, 'interactions.csv'))
    except Exception as e:
        return jsonify({"ok": False, "error": f"Failed to load recommendation data files: {e}"}), 500

    user_style = None
    
    # Try finding in users.csv
    user_row = None
    try:
        user_id_int = int(user_id)
        user_rows = users_df[users_df['user_id'] == user_id_int]
        if not user_rows.empty:
            user_row = user_rows.iloc[0]
    except ValueError:
        pass
        
    if user_row is not None:
        user_style = user_row['learning_style']
    else:
        # Check local DB/Mongo
        if mongo_db is not None:
            try:
                quiz_doc = mongo_db["quiz_results"].find_one({"userId": user_id, "quizType": "vark"})
                if quiz_doc:
                    user_style = quiz_doc.get("learningStyle")
            except Exception as e:
                print(f"Error querying local DB for recommendations: {e}")
                
    if not user_style:
        user_style = "Visual"  # fallback

    # Compute score for all courses
    interacted_ids = set()
    if user_row is not None:
        user_id_int = int(user_id)
        interacted_ids = set(interactions_df[interactions_df['user_id'] == user_id_int]['content_id'].tolist())

    # Average ratings from users with same learning style
    style_users = users_df[users_df['learning_style'] == user_style]['user_id'].tolist()
    style_interactions = interactions_df[interactions_df['user_id'].isin(style_users)]
    avg_ratings = style_interactions.groupby('content_id')['rating'].mean().to_dict()

    scores = []
    for _, row in content_df.iterrows():
        c_id = int(row['content_id'])
        c_title = str(row['title'])
        c_desc = str(row['description'])
        c_cat = str(row['category'])
        c_diff = str(row['difficulty'])
        c_rating = float(row['rating'])
        
        # Base score is rating
        score = c_rating
        
        # Collaborative filtering boost
        if c_id in avg_ratings:
            score += avg_ratings[c_id] * 0.5
            
        # Category preference boost based on learning style
        style_boost = 0.0
        if user_style == 'Visual':
            if c_cat.lower() in ['math', 'mathematics', 'science', 'computer science', 'engineering']:
                style_boost = 0.8
        elif user_style == 'Auditory':
            if c_cat.lower() in ['language arts', 'social science', 'psychology', 'philosophy']:
                style_boost = 0.8
        elif user_style == 'Reading/Writing':
            if c_cat.lower() in ['language arts', 'history', 'law', 'philosophy']:
                style_boost = 0.8
        elif user_style == 'Kinesthetic':
            if c_diff.lower() == 'hard' or c_cat.lower() in ['engineering', 'computer science', 'medicine']:
                style_boost = 0.8
                
        score += style_boost
        
        # De-prioritize already completed
        if c_id in interacted_ids:
            score -= 2.0
            
        scores.append({
            "content_id": c_id,
            "title": c_title,
            "description": c_desc,
            "category": c_cat,
            "difficulty": c_diff,
            "rating": c_rating,
            "score": score
        })
        
    scores.sort(key=lambda x: x['score'], reverse=True)
    
    # Return Top N
    recommendations = scores[:limit]
    
    return jsonify({
        "ok": True,
        "learningStyle": user_style,
        "recommendations": recommendations
    })


if __name__ == '__main__':
    app.run(debug=True)
