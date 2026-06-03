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
    
    # Sync to SQLite recommendations DB and clear cache
    if quiz_type == "vark" and learning_style:
        try:
            RecommendationDB.upsert_user_style(user_id, learning_style)
        except Exception as e:
            print(f"Error syncing user style to recommendations DB: {e}")
            
    try:
        get_recommendation_list.cache_clear()
    except Exception:
        pass

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


# --- ADVANCED RECOMMENDATION SYSTEM & CACHING INTEGRATION ---
import yaml
import logging
import sqlite3
import json
import sys
from functools import lru_cache, wraps
from flask import Response

# Path setup
_ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(_ROOT, "data", "recommendation_config.yaml")
RECS_DB_PATH = os.path.join(_ROOT, "data", "recommendations.db")

# Load configuration
try:
    with open(CONFIG_PATH, "r") as f:
        recs_config = yaml.safe_load(f)
except Exception as e:
    recs_config = {
        "model": {"path": "data/model/lightfm.pkl"},
        "weights": {"collaborative": 0.5, "style_boost": 0.8, "already_seen_penalty": 2.0},
        "pagination": {"default_limit": 5, "max_limit": 50},
        "logging": {"level": "INFO", "file": "logs/recommendations.log"},
        "admin_demo": {"enabled": True, "auth": "basic", "username": "admin", "password": "admin123"}
    }

# Configure logging
log_file = recs_config.get("logging", {}).get("file", "logs/recommendations.log")
log_level_str = recs_config.get("logging", {}).get("level", "INFO")
log_level = getattr(logging, log_level_str.upper(), logging.INFO)

os.makedirs(os.path.dirname(os.path.join(_ROOT, log_file)), exist_ok=True)
logging.basicConfig(
    level=log_level,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(os.path.join(_ROOT, log_file)),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("recommendations")
logger.info("Recommendation system logging initialized.")

# Load custom model
from recommender import HybridRecommender
MODEL_PATH = os.path.join(_ROOT, recs_config["model"]["path"])
CONTENT_IDX_PATH = os.path.join(_ROOT, "data", "model", "content_index.pkl")

recs_model = None
recs_user_map = {}
recs_item_map = {}

def load_recs_model():
    global recs_model, recs_user_map, recs_item_map
    if os.path.exists(MODEL_PATH) and os.path.exists(CONTENT_IDX_PATH):
        try:
            recs_model = joblib.load(MODEL_PATH)
            idx_maps = joblib.load(CONTENT_IDX_PATH)
            recs_user_map = idx_maps.get("user_map", {})
            recs_item_map = idx_maps.get("item_map", {})
            logger.info("Hybrid recommender model and index maps loaded successfully.")
        except Exception as e:
            logger.error(f"Error loading hybrid recommender model files: {e}")
    else:
        logger.warning("Hybrid recommender model files not found. Using fallback scoring.")

load_recs_model()

# SQLite Database Helper
class RecommendationDB:
    @staticmethod
    def get_user_style(user_id_str):
        try:
            user_id_int = int(user_id_str)
            with sqlite3.connect(RECS_DB_PATH) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT learning_style FROM users WHERE user_id = ?", (user_id_int,))
                row = cursor.fetchone()
                if row:
                    return row[0]
        except ValueError:
            pass

        if mongo_db is not None:
            try:
                quiz_doc = mongo_db["quiz_results"].find_one({"userId": user_id_str, "quizType": "vark"})
                if quiz_doc:
                    return quiz_doc.get("learningStyle")
            except Exception as e:
                logger.error(f"Error querying mongo_db/SQLiteAdapter: {e}")
        return "Visual"

    @staticmethod
    def upsert_user_style(user_id_str, learning_style):
        try:
            user_id_int = int(user_id_str)
            with sqlite3.connect(RECS_DB_PATH) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO users (user_id, learning_style) 
                    VALUES (?, ?)
                    ON CONFLICT(user_id) DO UPDATE SET learning_style = excluded.learning_style
                """, (user_id_int, learning_style))
                conn.commit()
            logger.info(f"Upserted style '{learning_style}' for user_id={user_id_int} in SQLite.")
        except ValueError:
            pass

    @staticmethod
    def get_user_interactions(user_id_str):
        try:
            user_id_int = int(user_id_str)
            with sqlite3.connect(RECS_DB_PATH) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT content_id FROM interactions WHERE user_id = ?", (user_id_int,))
                return {row[0] for row in cursor.fetchall()}
        except ValueError:
            return set()

    @staticmethod
    def get_all_content():
        with sqlite3.connect(RECS_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT content_id, title, description, category, difficulty, rating FROM content")
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]

    @staticmethod
    def get_average_ratings_by_style(learning_style):
        with sqlite3.connect(RECS_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT i.content_id, AVG(i.rating) 
                FROM interactions i
                JOIN users u ON i.user_id = u.user_id
                WHERE u.learning_style = ?
                GROUP BY i.content_id
            """, (learning_style,))
            return {row[0]: row[1] for row in cursor.fetchall()}

# Cache recommendations for 128 users
@lru_cache(maxsize=128)
def get_recommendation_list(user_id):
    logger.info(f"Computing recommendations for user_id={user_id} (cache miss).")
    user_style = RecommendationDB.get_user_style(user_id)
    interacted_ids = RecommendationDB.get_user_interactions(user_id)
    avg_ratings = RecommendationDB.get_average_ratings_by_style(user_style)
    all_content = RecommendationDB.get_all_content()
    
    model_scores = {}
    use_model = False
    
    if recs_model is not None:
        try:
            user_id_int = int(user_id)
            if user_id_int in recs_user_map:
                u_idx = recs_user_map[user_id_int]
                item_ids = [c["content_id"] for c in all_content]
                item_indices = [recs_item_map[cid] for cid in item_ids if cid in recs_item_map]
                
                if len(item_indices) == len(item_ids):
                    preds = recs_model.predict(u_idx, item_indices)
                    model_scores = dict(zip(item_ids, preds))
                    use_model = True
        except Exception as e:
            logger.error(f"Error computing model predictions: {e}")
            
    w_collab = recs_config["weights"]["collaborative"]
    w_style = recs_config["weights"]["style_boost"]
    w_penalty = recs_config["weights"]["already_seen_penalty"]
    
    scored_items = []
    for item in all_content:
        c_id = item["content_id"]
        c_rating = item["rating"] or 0.0
        c_cat = item["category"] or ""
        c_diff = item["difficulty"] or ""
        
        score = c_rating
        
        if use_model and c_id in model_scores:
            score += model_scores[c_id] * w_collab
        elif c_id in avg_ratings:
            score += avg_ratings[c_id] * w_collab
            
        style_boost = 0.0
        if user_style == 'Visual':
            if c_cat.lower() in ['math', 'mathematics', 'science', 'computer science', 'engineering']:
                style_boost = w_style
        elif user_style == 'Auditory':
            if c_cat.lower() in ['language arts', 'social science', 'psychology', 'philosophy']:
                style_boost = w_style
        elif user_style == 'Reading/Writing':
            if c_cat.lower() in ['language arts', 'history', 'law', 'philosophy']:
                style_boost = w_style
        elif user_style == 'Kinesthetic':
            if c_diff.lower() == 'hard' or c_cat.lower() in ['engineering', 'computer science', 'medicine']:
                style_boost = w_style
                
        score += style_boost
        
        if c_id in interacted_ids:
            score -= w_penalty
            
        scored_items.append({
            "content_id": c_id,
            "title": item["title"],
            "description": item["description"],
            "category": c_cat,
            "difficulty": c_diff,
            "rating": c_rating,
            "score": float(score)
        })
        
    scored_items.sort(key=lambda x: x['score'], reverse=True)
    return user_style, scored_items

@app.route("/api/recommendations", methods=["GET"])
def get_recommendations():
    user_id = request.args.get("userId", "local")
    limit = request.args.get("limit", str(recs_config["pagination"]["default_limit"]))
    offset = request.args.get("offset", "0")
    
    try:
        limit = int(limit)
    except ValueError:
        limit = recs_config["pagination"]["default_limit"]
        
    try:
        offset = int(offset)
        if offset < 0:
            offset = 0
    except ValueError:
        offset = 0
        
    max_limit = recs_config["pagination"]["max_limit"]
    if limit > max_limit:
        limit = max_limit
    elif limit <= 0:
        limit = recs_config["pagination"]["default_limit"]

    try:
        user_style, scored_items = get_recommendation_list(user_id)
        total_count = len(scored_items)
        paginated_recs = scored_items[offset : offset + limit]
        
        logger.info(f"Served {len(paginated_recs)} recommendations for user_id={user_id} (offset={offset}, limit={limit}, total={total_count})")
        return jsonify({
            "ok": True,
            "learningStyle": user_style,
            "recommendations": paginated_recs,
            "total_count": total_count,
            "offset": offset,
            "limit": limit
        })
    except Exception as e:
        logger.error(f"Error serving recommendations for user_id={user_id}: {e}", exc_info=True)
        return jsonify({"ok": False, "error": str(e)}), 500

# --- ADMIN DECORATOR & API ROUTING ---
def check_auth(username, password):
    config_user = recs_config.get("admin_demo", {}).get("username", "admin")
    config_pass = recs_config.get("admin_demo", {}).get("password", "admin123")
    return username == config_user and password == config_pass

def authenticate():
    return Response(
        'Could not verify your access credentials.\n'
        'Please enter correct basic auth username and password.', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'}
    )

def requires_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if recs_config.get("admin_demo", {}).get("auth") == "none":
            return f(*args, **kwargs)
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return authenticate()
        return f(*args, **kwargs)
    return decorated

@app.route("/admin/recommendations", methods=["GET"])
@requires_auth
def admin_recommendations():
    return ADMIN_HTML_TEMPLATE

@app.route("/admin/api/users", methods=["GET"])
@requires_auth
def admin_list_users():
    try:
        with sqlite3.connect(RECS_DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT user_id, learning_style FROM users LIMIT 100")
            users = [{"user_id": row[0], "learning_style": row[1]} for row in cursor.fetchall()]
        return jsonify({"ok": True, "users": users})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@app.route("/admin/api/weights", methods=["POST"])
@requires_auth
def admin_update_weights():
    data = request.get_json() or {}
    logger.info(f"Admin updating weights: {data}")
    try:
        w_collab = float(data.get("collaborative", recs_config["weights"]["collaborative"]))
        w_style = float(data.get("style_boost", recs_config["weights"]["style_boost"]))
        w_penalty = float(data.get("already_seen_penalty", recs_config["weights"]["already_seen_penalty"]))
        
        recs_config["weights"]["collaborative"] = w_collab
        recs_config["weights"]["style_boost"] = w_style
        recs_config["weights"]["already_seen_penalty"] = w_penalty
        
        with open(CONFIG_PATH, "w") as f:
            yaml.safe_dump(recs_config, f)
            
        get_recommendation_list.cache_clear()
        logger.info("Weights updated successfully and cache cleared.")
        return jsonify({"ok": True})
    except Exception as e:
        logger.error(f"Error updating weights: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500

@app.route("/admin/api/train", methods=["POST"])
@requires_auth
def admin_train_model():
    logger.info("Admin triggered model training.")
    try:
        import subprocess
        script_path = os.path.join(_ROOT, "scripts", "train_lightfm.py")
        result = subprocess.run([sys.executable, script_path], capture_output=True, text=True, check=True)
        
        load_recs_model()
        get_recommendation_list.cache_clear()
        
        logger.info("Model retrained and loaded successfully.")
        return jsonify({"ok": True, "output": result.stdout})
    except Exception as e:
        logger.error(f"Error training model: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500

@app.route("/admin/api/logs", methods=["GET"])
@requires_auth
def admin_get_logs():
    try:
        log_path = os.path.join(_ROOT, recs_config.get("logging", {}).get("file", "logs/recommendations.log"))
        if not os.path.exists(log_path):
            return jsonify({"ok": True, "logs": "No log file found yet."})
        with open(log_path, "r") as f:
            lines = f.readlines()
        return jsonify({"ok": True, "logs": "".join(lines[-30:])})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

# HTML Template variable definition
ADMIN_HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>EduMindAI - Admin Dashboard Đề Xuất</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #8A2BE2;
            --primary-hover: #7A1FD2;
            --primary-glow: rgba(138, 43, 226, 0.4);
            --secondary: #00F0FF;
            --accent: #FF007F;
            --bg-dark: #090A0F;
            --panel-bg: rgba(18, 20, 32, 0.75);
            --card-bg: rgba(255, 255, 255, 0.03);
            --border: rgba(255, 255, 255, 0.08);
            --border-hover: rgba(255, 255, 255, 0.15);
            --text: #F8FAFC;
            --text-muted: #94A3B8;
            --success: #10B981;
            --warning: #F59E0B;
        }
        
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'Outfit', sans-serif;
            background-color: var(--bg-dark);
            background-image: 
                radial-gradient(at 0% 0%, rgba(138, 43, 226, 0.15) 0px, transparent 50%),
                radial-gradient(at 100% 100%, rgba(0, 240, 255, 0.1) 0px, transparent 50%);
            color: var(--text);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        header {
            background: rgba(10, 11, 20, 0.8);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid var(--border);
            padding: 16px 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        
        .logo-section h1 {
            font-size: 24px;
            font-weight: 700;
            background: linear-gradient(45deg, var(--primary), var(--secondary));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            letter-spacing: 0.5px;
        }
        
        .logo-section p {
            font-size: 12px;
            color: var(--text-muted);
        }
        
        .status-badge {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            border-radius: 99px;
            font-size: 12px;
            font-weight: 500;
            background: rgba(16, 185, 129, 0.1);
            color: var(--success);
            border: 1px solid rgba(16, 185, 129, 0.2);
        }
        
        .status-badge.missing {
            background: rgba(245, 158, 11, 0.1);
            color: var(--warning);
            border: 1px solid rgba(245, 158, 11, 0.2);
        }
        
        .status-badge.loading {
            background: rgba(138, 43, 226, 0.1);
            color: var(--primary);
            border: 1px solid rgba(138, 43, 226, 0.2);
        }
        
        .container {
            display: grid;
            grid-template-columns: 350px 1fr;
            gap: 24px;
            padding: 40px;
            flex-grow: 1;
            max-width: 1600px;
            width: 100%;
            margin: 0 auto;
        }
        
        aside {
            display: flex;
            flex-direction: column;
            gap: 24px;
        }
        
        main {
            display: flex;
            flex-direction: column;
            gap: 24px;
        }
        
        .card {
            background: var(--panel-bg);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 24px;
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            transition: all 0.3s ease;
        }
        
        .card:hover {
            border-color: var(--border-hover);
        }
        
        .card-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 20px;
            border-bottom: 1px solid var(--border);
            padding-bottom: 10px;
            color: var(--text);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .search-box {
            position: relative;
            margin-bottom: 16px;
        }
        
        .search-box input {
            width: 100%;
            padding: 12px 16px;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid var(--border);
            border-radius: 8px;
            color: var(--text);
            font-family: inherit;
            outline: none;
            transition: border-color 0.2s;
        }
        
        .search-box input:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 2px var(--primary-glow);
        }
        
        .user-list {
            height: 250px;
            overflow-y: auto;
            border: 1px solid var(--border);
            border-radius: 8px;
            background: rgba(0, 0, 0, 0.2);
        }
        
        .user-item {
            padding: 12px 16px;
            cursor: pointer;
            border-bottom: 1px solid rgba(255, 255, 255, 0.02);
            transition: all 0.2s;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .user-item:hover {
            background: rgba(255, 255, 255, 0.05);
        }
        
        .user-item.active {
            background: var(--primary-glow);
            border-left: 4px solid var(--primary);
        }
        
        .badge {
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 10px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .badge.visual { background: rgba(0, 240, 255, 0.15); color: var(--secondary); border: 1px solid rgba(0, 240, 255, 0.3); }
        .badge.auditory { background: rgba(255, 0, 127, 0.15); color: var(--accent); border: 1px solid rgba(255, 0, 127, 0.3); }
        .badge.reading { background: rgba(138, 43, 226, 0.15); color: #B19FFB; border: 1px solid rgba(138, 43, 226, 0.3); }
        .badge.kinesthetic { background: rgba(16, 185, 129, 0.15); color: var(--success); border: 1px solid rgba(16, 185, 129, 0.3); }
        
        .slider-group {
            margin-bottom: 20px;
        }
        
        .slider-label {
            display: flex;
            justify-content: space-between;
            font-size: 14px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }
        
        .slider-label span.val {
            color: var(--text);
            font-weight: 600;
        }
        
        .slider-input {
            width: 100%;
            height: 6px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 5px;
            outline: none;
            -webkit-appearance: none;
        }
        
        .slider-input::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 16px;
            height: 16px;
            border-radius: 50%;
            background: var(--primary);
            cursor: pointer;
            box-shadow: 0 0 8px var(--primary-glow);
            transition: transform 0.1s;
        }
        
        .slider-input::-webkit-slider-thumb:hover {
            transform: scale(1.2);
        }
        
        .btn {
            width: 100%;
            padding: 12px;
            border: none;
            border-radius: 8px;
            font-family: inherit;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
            transition: all 0.2s;
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 8px;
        }
        
        .btn-primary {
            background: var(--primary);
            color: white;
            box-shadow: 0 4px 12px var(--primary-glow);
        }
        
        .btn-primary:hover {
            background: var(--primary-hover);
            transform: translateY(-1px);
        }
        
        .btn-secondary {
            background: rgba(255, 255, 255, 0.05);
            color: var(--text);
            border: 1px solid var(--border);
        }
        
        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.1);
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        
        th, td {
            text-align: left;
            padding: 14px 16px;
            border-bottom: 1px solid var(--border);
        }
        
        th {
            font-weight: 600;
            color: var(--text-muted);
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        td {
            font-size: 15px;
        }
        
        tr:hover td {
            background: rgba(255, 255, 255, 0.01);
        }
        
        .score-pill {
            padding: 4px 8px;
            border-radius: 6px;
            font-weight: 700;
            background: rgba(138, 43, 226, 0.15);
            color: #C084FC;
            border: 1px solid rgba(138, 43, 226, 0.25);
            font-family: monospace;
            font-size: 14px;
        }
        
        .console {
            background: #050608;
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 16px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 12px;
            color: #38BDF8;
            height: 150px;
            overflow-y: auto;
            white-space: pre-wrap;
        }
        
        .pagination {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 20px;
        }
        
        .page-info {
            font-size: 14px;
            color: var(--text-muted);
        }
        
        .page-btns {
            display: flex;
            gap: 10px;
        }
        
        .page-btn {
            padding: 8px 16px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border);
            border-radius: 6px;
            color: var(--text);
            cursor: pointer;
            transition: all 0.2s;
        }
        
        .page-btn:hover:not(:disabled) {
            background: rgba(255, 255, 255, 0.1);
        }
        
        .page-btn:disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }
        
        .spinner {
            width: 18px;
            height: 18px;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 0.8s linear infinite;
            display: none;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <header>
        <div class="logo-section">
            <h1>EduMindAI Recommendation Engine</h1>
            <p>Admin Dashboard &amp; Demo Panel</p>
        </div>
        <div style="display: flex; align-items: center; gap: 16px;">
            <div id="modelStatus" class="status-badge">Đang kiểm tra...</div>
        </div>
    </header>
    
    <div class="container">
        <aside>
            <div class="card">
                <div class="card-title">Bộ Điều Khiển</div>
                <div class="slider-group">
                    <div class="slider-label">
                        <span>Trọng số Hợp Tác Lọc (Collaborative)</span>
                        <span class="val" id="valCollab">0.5</span>
                    </div>
                    <input type="range" class="slider-input" id="sliderCollab" min="0" max="2" step="0.1" value="0.5">
                </div>
                <div class="slider-group">
                    <div class="slider-label">
                        <span>Tăng cường Học phong (Style Boost)</span>
                        <span class="val" id="valStyle">0.8</span>
                    </div>
                    <input type="range" class="slider-input" id="sliderStyle" min="0" max="2" step="0.1" value="0.8">
                </div>
                <div class="slider-group">
                    <div class="slider-label">
                        <span>Hình phạt Đã xem (Penalty)</span>
                        <span class="val" id="valPenalty">2.0</span>
                    </div>
                    <input type="range" class="slider-input" id="sliderPenalty" min="0" max="5" step="0.2" value="2.0">
                </div>
                <button class="btn btn-primary" id="btnSaveWeights" style="margin-bottom: 12px;">Cập nhật Trọng số</button>
                <button class="btn btn-secondary" id="btnTrainModel">
                    <div class="spinner" id="trainSpinner"></div>
                    <span>Huấn luyện lại Mô hình</span>
                </button>
            </div>
            
            <div class="card">
                <div class="card-title">Danh Sách Học Viên</div>
                <div class="search-box">
                    <input type="text" id="userSearch" placeholder="Tìm kiếm userId...">
                </div>
                <div class="user-list" id="userList">
                    <!-- Loaded dynamically -->
                </div>
            </div>
        </aside>
        
        <main>
            <div class="card" style="margin-bottom: 0;">
                <div class="card-title">
                    <span>Kết Quả Đề Xuất Khóa Học</span>
                    <span id="currentUserStyle" class="badge visual" style="display: none;">VISUAL</span>
                </div>
                
                <div style="overflow-x: auto;">
                    <table id="recsTable">
                        <thead>
                            <tr>
                                <th style="width: 80px;">Hạng</th>
                                <th>Khóa học</th>
                                <th>Thể loại</th>
                                <th>Độ khó</th>
                                <th>Đánh giá gốc</th>
                                <th style="width: 120px;">Điểm số</th>
                            </tr>
                        </thead>
                        <tbody id="recsBody">
                            <tr>
                                <td colspan="6" style="text-align: center; color: var(--text-muted);">Hãy chọn học viên ở danh sách bên trái để hiển thị gợi ý.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                
                <div class="pagination">
                    <div class="page-info" id="pageInfo">Hiển thị 0 khóa học</div>
                    <div class="page-btns">
                        <button class="page-btn" id="btnPrev" disabled>Trang trước</button>
                        <button class="page-btn" id="btnNext" disabled>Trang sau</button>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <div class="card-title">Bảng Console Nhật Ký (Live Logs)</div>
                <div class="console" id="consoleLogs">Loading logs...</div>
            </div>
        </main>
    </div>

    <script>
        let currentUserId = null;
        let currentOffset = 0;
        const limit = 5;
        let allUsers = [];
        
        const setupSlider = (sliderId, valId) => {
            const slider = document.getElementById(sliderId);
            const val = document.getElementById(valId);
            slider.addEventListener('input', () => {
                val.textContent = parseFloat(slider.value).toFixed(1);
            });
        };
        setupSlider('sliderCollab', 'valCollab');
        setupSlider('sliderStyle', 'valStyle');
        setupSlider('sliderPenalty', 'valPenalty');
        
        async function loadUsers() {
            try {
                const res = await fetch('/admin/api/users');
                const data = await res.json();
                if (data.ok) {
                    allUsers = data.users;
                    renderUserList(allUsers);
                }
            } catch (e) {
                console.error("Error loading users", e);
            }
        }
        
        function renderUserList(users) {
            const container = document.getElementById('userList');
            container.innerHTML = '';
            users.forEach(u => {
                const item = document.createElement('div');
                item.className = 'user-item';
                if (currentUserId == u.user_id) {
                    item.className += ' active';
                }
                item.onclick = () => selectUser(u.user_id);
                
                const badgeClass = u.learning_style.toLowerCase() === 'reading/writing' ? 'reading' : u.learning_style.toLowerCase();
                item.innerHTML = `
                    <span>Học viên #${u.user_id}</span>
                    <span class="badge ${badgeClass}">${u.learning_style}</span>
                `;
                container.appendChild(item);
            });
        }
        
        document.getElementById('userSearch').addEventListener('input', (e) => {
            const q = e.target.value.toLowerCase().trim();
            const filtered = allUsers.filter(u => u.user_id.toString().includes(q) || u.learning_style.toLowerCase().includes(q));
            renderUserList(filtered);
        });
        
        async function selectUser(userId) {
            currentUserId = userId;
            currentOffset = 0;
            
            const items = document.querySelectorAll('.user-item');
            items.forEach(el => el.classList.remove('active'));
            const userItems = Array.from(document.querySelectorAll('.user-item span'));
            const match = userItems.find(el => el.textContent.includes('#' + userId));
            if (match && match.parentElement) {
                match.parentElement.classList.add('active');
            }
            
            await loadRecommendations();
        }
        
        async function loadRecommendations() {
            if (!currentUserId) return;
            const tableBody = document.getElementById('recsBody');
            tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">Đang tải dữ liệu...</td></tr>`;
            
            try {
                const res = await fetch(`/api/recommendations?userId=${currentUserId}&limit=${limit}&offset=${currentOffset}`);
                const data = await res.json();
                if (data.ok) {
                    const styleBadge = document.getElementById('currentUserStyle');
                    styleBadge.style.display = 'inline-block';
                    styleBadge.textContent = data.learningStyle;
                    styleBadge.className = 'badge ' + (data.learningStyle.toLowerCase() === 'reading/writing' ? 'reading' : data.learningStyle.toLowerCase());
                    
                    tableBody.innerHTML = '';
                    if (data.recommendations.length === 0) {
                        tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">Không tìm thấy khóa học nào.</td></tr>`;
                    } else {
                        data.recommendations.forEach((rec, idx) => {
                            const tr = document.createElement('tr');
                            const rank = currentOffset + idx + 1;
                            tr.innerHTML = `
                                <td><strong style="color: var(--text-muted);">#${rank}</strong></td>
                                <td>
                                    <div style="font-weight: 600;">${rec.title}</div>
                                    <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">${rec.description || 'Không có mô tả'}</div>
                                </td>
                                <td><span style="opacity: 0.85;">${rec.category}</span></td>
                                <td><span style="opacity: 0.85;">${rec.difficulty}</span></td>
                                <td><strong style="color: var(--warning);">&#9733; ${parseFloat(rec.rating).toFixed(1)}</strong></td>
                                <td><span class="score-pill">${parseFloat(rec.score).toFixed(2)}</span></td>
                            `;
                            tableBody.appendChild(tr);
                        });
                    }
                    
                    const total = data.total_count || 0;
                    const start = total === 0 ? 0 : currentOffset + 1;
                    const end = Math.min(currentOffset + limit, total);
                    document.getElementById('pageInfo').textContent = `Hiển thị ${start}-${end} trong tổng số ${total} khóa học`;
                    
                    document.getElementById('btnPrev').disabled = currentOffset === 0;
                    document.getElementById('btnNext').disabled = end >= total;
                } else {
                    tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--accent);">Lỗi: ${data.error}</td></tr>`;
                }
            } catch (e) {
                tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--accent);">Lỗi kết nối tới máy chủ.</td></tr>`;
            }
        }
        
        document.getElementById('btnPrev').onclick = async () => {
            if (currentOffset >= limit) {
                currentOffset -= limit;
                await loadRecommendations();
            }
        };
        document.getElementById('btnNext').onclick = async () => {
            currentOffset += limit;
            await loadRecommendations();
        };
        
        document.getElementById('btnSaveWeights').onclick = async () => {
            const collaborative = parseFloat(document.getElementById('sliderCollab').value);
            const style_boost = parseFloat(document.getElementById('sliderStyle').value);
            const already_seen_penalty = parseFloat(document.getElementById('sliderPenalty').value);
            
            try {
                const res = await fetch('/admin/api/weights', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ collaborative, style_boost, already_seen_penalty })
                });
                const data = await res.json();
                if (data.ok) {
                    alert("Cập nhật trọng số thành công!");
                    await loadRecommendations();
                    await fetchLogs();
                } else {
                    alert("Cập nhật thất bại: " + data.error);
                }
            } catch (e) {
                alert("Lỗi kết nối khi cập nhật trọng số.");
            }
        };
        
        document.getElementById('btnTrainModel').onclick = async () => {
            const btn = document.getElementById('btnTrainModel');
            const spinner = document.getElementById('trainSpinner');
            btn.disabled = true;
            spinner.style.display = 'inline-block';
            
            try {
                const res = await fetch('/admin/api/train', { method: 'POST' });
                const data = await res.json();
                if (data.ok) {
                    alert("Huấn luyện mô hình Hybrid thành công!");
                    checkModelStatus();
                    await loadRecommendations();
                    await fetchLogs();
                } else {
                    alert("Huấn luyện thất bại: " + data.error);
                }
            } catch (e) {
                alert("Lỗi kết nối khi huấn luyện mô hình.");
            } finally {
                btn.disabled = false;
                spinner.style.display = 'none';
            }
        };
        
        async function fetchLogs() {
            try {
                const res = await fetch('/admin/api/logs');
                const data = await res.json();
                if (data.ok) {
                    const consoleEl = document.getElementById('consoleLogs');
                    consoleEl.textContent = data.logs || "Chưa có nhật ký nào.";
                    consoleEl.scrollTop = consoleEl.scrollHeight;
                }
            } catch (e) {}
        }
        
        async function checkModelStatus() {
            const badge = document.getElementById('modelStatus');
            try {
                const res = await fetch('/api/recommendations?userId=1&limit=1');
                const data = await res.json();
                if (data.ok) {
                    badge.textContent = "MÔ HÌNH: HYBRID SẴN SÀNG";
                    badge.className = "status-badge";
                } else {
                    badge.textContent = "MÔ HÌNH: CHƯA HUẤN LUYỆN";
                    badge.className = "status-badge missing";
                }
            } catch(e) {
                badge.textContent = "LỖI KẾT NỐI MÁY CHỦ";
                badge.className = "status-badge missing";
            }
        }
        
        window.onload = async () => {
            await loadUsers();
            await fetchLogs();
            await checkModelStatus();
            setInterval(fetchLogs, 8000);
        };
    </script>
</body>
</html>"""

if __name__ == '__main__':
    app.run(debug=True)

