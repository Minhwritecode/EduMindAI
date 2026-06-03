# tests/test_recommendations.py
import json
import base64
import pytest
import os
import sys

# Ensure project root is on path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import app, get_recommendation_list

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        # Clear cache before each test
        get_recommendation_list.cache_clear()
        yield client

def test_recommendations_default(client):
    response = client.get('/api/recommendations?userId=1')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['ok'] is True
    assert 'recommendations' in data
    assert 'learningStyle' in data
    assert 'total_count' in data
    assert len(data['recommendations']) <= 5  # default limit is 5

def test_recommendations_pagination(client):
    # Fetch with limit=2, offset=0
    res1 = client.get('/api/recommendations?userId=1&limit=2&offset=0')
    assert res1.status_code == 200
    data1 = json.loads(res1.data)
    assert len(data1['recommendations']) == 2
    
    # Fetch with limit=2, offset=2
    res2 = client.get('/api/recommendations?userId=1&limit=2&offset=2')
    assert res2.status_code == 200
    data2 = json.loads(res2.data)
    assert len(data2['recommendations']) == 2
    
    # Ensure they are different items
    id1 = [item['content_id'] for item in data1['recommendations']]
    id2 = [item['content_id'] for item in data2['recommendations']]
    assert set(id1).isdisjoint(set(id2))

def test_admin_auth_required(client):
    # Without Auth
    response = client.get('/admin/recommendations')
    assert response.status_code == 401
    
    # With wrong Auth
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(b'admin:wrongpassword').decode('utf-8')
    }
    response = client.get('/admin/recommendations', headers=headers)
    assert response.status_code == 401

def test_admin_authorized(client):
    # With correct Auth
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(b'admin:admin123').decode('utf-8')
    }
    response = client.get('/admin/recommendations', headers=headers)
    assert response.status_code == 200
    assert b'EduMindAI Recommendation Engine' in response.data

def test_admin_update_weights(client):
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(b'admin:admin123').decode('utf-8')
    }
    # Update weights
    payload = {
        'collaborative': 1.5,
        'style_boost': 1.2,
        'already_seen_penalty': 3.0
    }
    res = client.post('/admin/api/weights', json=payload, headers=headers)
    assert res.status_code == 200
    data = json.loads(res.data)
    assert data['ok'] is True

def test_admin_get_users(client):
    headers = {
        'Authorization': 'Basic ' + base64.b64encode(b'admin:admin123').decode('utf-8')
    }
    response = client.get('/admin/api/users', headers=headers)
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['ok'] is True
    assert 'users' in data
