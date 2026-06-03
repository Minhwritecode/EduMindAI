#!/usr/bin/env python3
"""train_lightfm.py
Train a hybrid matrix factorization model on the EduMindAI recommendation data.
The script:
1. Loads users, content, and interactions from the SQLite DB.
2. Builds an interaction matrix (users x items).
3. Trains the HybridRecommender model.
4. Saves the trained model to `data/model/lightfm.pkl` using joblib.
5. Saves the index maps to `data/model/content_index.pkl`.
"""
import os
import sys
import joblib
import numpy as np
import pandas as pd
from scipy import sparse

# Project root
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(ROOT)

from recommender import HybridRecommender

DB_PATH = os.path.join(ROOT, "data", "recommendations.db")
MODEL_PATH = os.path.join(ROOT, "data", "model", "lightfm.pkl")
CONTENT_IDX_PATH = os.path.join(ROOT, "data", "model", "content_index.pkl")

def load_data():
    import sqlite3
    conn = sqlite3.connect(DB_PATH)
    users = pd.read_sql("SELECT DISTINCT user_id FROM users", conn)
    items = pd.read_sql("SELECT DISTINCT content_id FROM content", conn)
    interactions = pd.read_sql("SELECT user_id, content_id, rating FROM interactions", conn)
    conn.close()
    return users, items, interactions

def build_interaction_matrix(users, items, interactions):
    # Map ids to sequential indices
    user_id_map = {int(uid): i for i, uid in enumerate(users['user_id'].tolist())}
    item_id_map = {int(cid): i for i, cid in enumerate(items['content_id'].tolist())}
    rows = interactions['user_id'].map(user_id_map).values
    cols = interactions['content_id'].map(item_id_map).values
    data = interactions['rating'].values.astype(np.float32)
    matrix = sparse.coo_matrix((data, (rows, cols)), shape=(len(user_id_map), len(item_id_map)))
    return matrix.tocsr(), user_id_map, item_id_map

def train():
    users, items, interactions = load_data()
    interaction_matrix, user_map, item_map = build_interaction_matrix(users, items, interactions)
    model = HybridRecommender(no_components=10, learning_rate=0.05, random_state=42)
    model.fit(interaction_matrix, epochs=30)
    # Save model and index maps
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    joblib.dump({"user_map": user_map, "item_map": item_map}, CONTENT_IDX_PATH)
    print(f"Hybrid model saved to {MODEL_PATH}")
    print(f"Index maps saved to {CONTENT_IDX_PATH}")

if __name__ == "__main__":
    train()
