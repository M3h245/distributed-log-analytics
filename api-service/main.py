from fastapi import FastAPI, Query
from fastapi.staticfiles import StaticFiles
from db import get_connection
import json
import os
import urllib.parse
import urllib.request

app = FastAPI()
app.mount("/ui", StaticFiles(directory="static", html=True), name="ui")

@app.get("/")
def health():
    return {"status": "ok"}


@app.get("/demo-send")
def demo_send(message: str = "ui event"):
    producer_url = os.getenv("PRODUCER_URL", "http://producer:8000")
    encoded_message = urllib.parse.quote(message)
    url = f"{producer_url}/send?message={encoded_message}"
    with urllib.request.urlopen(url, timeout=5) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload)


@app.get("/logs")
def get_logs(limit: int = 100, from_timestamp: float = 0):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, message, timestamp
        FROM logs
        WHERE timestamp >= %s
        ORDER BY timestamp DESC
        LIMIT %s
        """,
        (from_timestamp, limit),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    logs = [{"id": row[0], "message": row[1], "timestamp": row[2]} for row in rows]
    return {"logs": logs}
