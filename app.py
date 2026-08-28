from flask import Flask, jsonify
import psycopg2
import os
import logging

logging.basicConfig(level=logging.INFO)
app = Flask(__name__)

DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'postgres')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASS = os.getenv('DB_PASS', 'postgres')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

@app.route('/')
def index():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute('''
        CREATE TABLE IF NOT EXISTS visits (
            id SERIAL PRIMARY KEY,
            count INT DEFAULT 0
        );
    ''')

    cur.execute('''
        INSERT INTO visits (id, count)
        VALUES (1, 0)
        ON CONFLICT (id) DO NOTHING;
    ''')

    cur.execute('UPDATE visits SET count = count + 1 WHERE id = 1;')

    cur.execute('SELECT count FROM visits WHERE id = 1;')
    count = cur.fetchone()[0]

    conn.commit()
    cur.close()
    conn.close()

    return jsonify({"message": "Hello from Flask + PostgreSQL!", "visits": count})

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({"status": "healthy", "db": "connected"})
    except Exception as e:
        return jsonify({"status": "unhealthy", "db": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
