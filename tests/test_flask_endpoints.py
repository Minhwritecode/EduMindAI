# tests/test_flask_endpoints.py
import os
import json
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_missing_text_returns_400(client):
    response = client.post('/api/predictLearningStyleFromText', json={})
    assert response.status_code == 400
    data = json.loads(response.data)
    assert 'error' in data

def test_invalid_route_returns_404(client):
    response = client.get('/nonexistent')
    assert response.status_code == 404
