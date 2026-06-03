#!/usr/bin/env python3
"""scripts/migrate_csv_to_sqlite.py

Migrate existing CSV files (users.csv, content.csv, interactions.csv) into a
SQLite database with appropriate indexes. This script is idempotent – it will
create the database if it does not exist and will skip rows that already
exist.
"""

import os
import sqlite3
import pandas as pd

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA_DIR = PROJECT_ROOT  # CSV files are in the project root
DB_PATH = os.path.join(PROJECT_ROOT, "data", "recommendations.db")

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

def _load_csv(name: str) -> pd.DataFrame:
    path = os.path.join(DATA_DIR, f"{name}.csv")
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path} not found")
    return pd.read_csv(path)

def _create_tables(conn: sqlite3.Connection):
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            user_id INTEGER PRIMARY KEY,
            learning_style TEXT NOT NULL
        );
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS content (
            content_id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            category TEXT,
            difficulty TEXT,
            rating REAL
        );
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS interactions (
            user_id INTEGER,
            content_id INTEGER,
            rating REAL,
            PRIMARY KEY (user_id, content_id)
        );
    """)
    # Indexes for fast look‑ups
    cur.execute("CREATE INDEX IF NOT EXISTS idx_user ON users(user_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_content ON content(content_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_inter_user ON interactions(user_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_inter_content ON interactions(content_id);")
    conn.commit()

def _upsert_dataframe(df: pd.DataFrame, table: str, conn: sqlite3.Connection, key_cols: list):
    cur = conn.cursor()
    for _, row in df.iterrows():
        cols = list(row.index)
        placeholders = ", ".join(["?" for _ in cols])
        sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders}) "
        sql += f"ON CONFLICT({', '.join(key_cols)}) DO UPDATE SET "
        sql += ", ".join([f"{c}=excluded.{c}" for c in cols if c not in key_cols])
        cur.execute(sql, tuple(row))
    conn.commit()

def main():
    conn = sqlite3.connect(DB_PATH)
    _create_tables(conn)

    # Users
    users_df = _load_csv('users')
    # Select only needed columns to match the users table schema
    users_df = users_df[['user_id', 'learning_style']]
    _upsert_dataframe(users_df, 'users', conn, ['user_id'])

    # Content
    content_df = _load_csv('content')
    content_df = content_df.rename(columns={
        'content_id': 'content_id',
        'title': 'title',
        'description': 'description',
        'category': 'category',
        'difficulty': 'difficulty',
        'rating': 'rating'
    })
    _upsert_dataframe(content_df, 'content', conn, ['content_id'])

    # Interactions
    inter_df = _load_csv('interactions')
    # Select only needed columns to match the interactions table schema
    inter_df = inter_df[['user_id', 'content_id', 'rating']]
    _upsert_dataframe(inter_df, 'interactions', conn, ['user_id', 'content_id'])

    conn.close()
    print(f"Migration completed – SQLite DB at {DB_PATH}")

if __name__ == "__main__":
    main()
