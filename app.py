import os
from datetime import datetime, timezone

from flask import Flask, request, jsonify
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
    CORS(app)

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
    return jsonify(
        {
            "ok": True,
            "mongo": mongo_db is not None,
        }
    )


@app.route("/api/notebooks", methods=["GET"])
def get_notebooks():
    if mongo_db is None:
        return jsonify({"ok": False, "error": "MongoDB not configured"}), 503
    user_id = request.args.get("userId", "local")
    docs = list(mongo_db["notebooks"].find({"userId": user_id}, projection={"_id": 0}))
    return jsonify({"ok": True, "notebooks": docs}), 200


@app.route("/api/notebooks", methods=["POST"])
def save_notebook():
    if mongo_db is None:
        return jsonify({"ok": False, "error": "MongoDB not configured"}), 503
    data = request.get_json(silent=True) or {}
    user_id = str(data.get("userId", "local"))
    notebook_id = str(data.get("id", ""))
    title = str(data.get("title", "Untitled Notebook"))
    text = str(data.get("text", ""))
    if not notebook_id:
        import uuid
        notebook_id = str(uuid.uuid4())
    
    mongo_db["notebooks"].update_one(
        {"userId": user_id, "id": notebook_id},
        {
            "$set": {
                "userId": user_id,
                "id": notebook_id,
                "title": title,
                "text": text,
                "updatedAt": datetime.now(timezone.utc),
            }
        },
        upsert=True,
    )
    return jsonify({"ok": True, "id": notebook_id}), 200


@app.route("/api/notebooks", methods=["DELETE"])
def delete_notebook():
    if mongo_db is None:
        return jsonify({"ok": False, "error": "MongoDB not configured"}), 503
    user_id = request.args.get("userId", "local")
    notebook_id = request.args.get("id", "")
    mongo_db["notebooks"].delete_one({"userId": user_id, "id": notebook_id})
    return jsonify({"ok": True}), 200


if __name__ == '__main__':
    app.run(debug=True)
