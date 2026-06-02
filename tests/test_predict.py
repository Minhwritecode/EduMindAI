# tests/test_predict.py
import json
from app import app

def test_predict_vark_text():
    client = app.test_client()
    payload = {"text": "I love watching videos and listening to lectures."}
    response = client.post("/api/predictLearningStyleFromText", json=payload)
    assert response.status_code == 200
    data = response.get_json()
    assert "learningStyle" in data
