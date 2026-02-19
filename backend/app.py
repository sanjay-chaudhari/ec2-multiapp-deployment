from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
import os

app = Flask(__name__)
CORS(app)

def get_db():
    return psycopg2.connect(os.environ.get("DATABASE_URL", "postgresql://myapp_user:password@localhost:5432/myapp_db"))

def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cur.close()
    conn.close()

@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/api/items", methods=["GET"])
def get_items():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT id, name, description, created_at FROM items ORDER BY created_at DESC")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([{"id": r[0], "name": r[1], "description": r[2], "created_at": str(r[3])} for r in rows])

@app.route("/api/items", methods=["POST"])
def create_item():
    data = request.json
    conn = get_db()
    cur = conn.cursor()
    cur.execute("INSERT INTO items (name, description) VALUES (%s, %s) RETURNING id", (data["name"], data.get("description", "")))
    item_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"id": item_id, "name": data["name"]}), 201

@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM items WHERE id = %s", (item_id,))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"deleted": item_id})

init_db()  # runs on startup whether via gunicorn or directly

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
