import os
from datetime import datetime, timezone

# THAY ĐỔI: Đã thêm make_response vào dòng import này
from flask import Flask, request, jsonify, make_response
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

try:
    from dotenv import load_dotenv
    load_dotenv()
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

app = Flask(__name__)
if CORS is not None:
    CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

mongo_uri = os.environ.get("MONGO_URI", "").strip()
mongo_db = None
if mongo_uri and MongoClient is not None:
    try:
        _client = MongoClient(mongo_uri, serverSelectionTimeoutMS=8000)
        mongo_db = _client["pm_edu_mind"]
        mongo_db.command("ping")
    except Exception as exc:  # noqa: BLE001
        print("MongoDB connection failed:", exc)
        mongo_db = None

# Load the dataset
df = pd.read_csv('learning_styles.csv')

# Preprocess data and train the model
X = df.drop('LearningStyle', axis=1)
y = df['LearningStyle']

model = RandomForestClassifier()
model.fit(X, y)

@app.route('/predictLearningStyle', methods=['POST'])
def predict_learning_style():
    data = request.get_json()
    question_data = pd.DataFrame(data, index=[0])
    prediction = model.predict(question_data)
    return jsonify({'learningStyle': prediction[0]})


@app.route("/health", methods=["GET"])
def health():
    return jsonify(
        {
            "ok": True,
            "mongo": mongo_db is not None,
        }
    )


@app.route("/api/notebooks", methods=["POST", "OPTIONS"])
def save_notebook_context():
    """Upsert notebook text for a user."""
    if request.method == 'OPTIONS':
        response = make_response(jsonify({'status': 'ok'}), 200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return response

    if mongo_db is None:
        return jsonify({"ok": False, "error": "MongoDB not configured. Set MONGO_URI in .env"}), 503
    
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

    response = make_response(jsonify({"ok": True}), 200)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route("/api/notebooks", methods=["GET", "OPTIONS"])
def get_notebook_context():
    """Get notebook text for a user."""
    if request.method == 'OPTIONS':
        response = make_response(jsonify({'status': 'ok'}), 200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return response

    if mongo_db is None:
        return jsonify({"ok": False, "error": "MongoDB not configured. Set MONGO_URI in .env"}), 503
    
    user_id = request.args.get("userId", "local")
    doc = mongo_db["notebook_contexts"].find_one(
        {"userId": user_id}, projection={"_id": 0, "text": 1}
    )
    text = (doc or {}).get("text", "")

    response = make_response(jsonify({"ok": True, "text": text}), 200)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route('/api/auth/register', methods=['POST', 'OPTIONS'])
def register():
    if request.method == 'OPTIONS':
        response = make_response(jsonify({'status': 'ok'}), 200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return response

    data = request.get_json(silent=True) or {}
    print("Dữ liệu đăng ký nhận được:", data)
    
    res_data = {"ok": True, "message": "Đăng ký thành công!"}
    response = make_response(jsonify(res_data), 201)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route('/api/auth/login', methods=['POST', 'OPTIONS'])
def login():
    if request.method == 'OPTIONS':
        response = make_response(jsonify({'status': 'ok'}), 200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return response

    data = request.get_json(silent=True) or {}
    
    res_data = {
        "ok": True,
        "message": "Đăng nhập thành công!",
        "userId": "local_mock_id",
        "username": "Duc Hoang"
    }
    
    response = make_response(jsonify(res_data), 200)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


if __name__ == '__main__':
    app.run(debug=True)