from fastapi import FastAPI
import redis
import psycopg2
import threading
import time
import os
import socket

app = FastAPI()
listener_thread = None

STREAM_NAME = os.getenv("REDIS_STREAM", "log_stream")
GROUP_NAME = os.getenv("REDIS_GROUP", "log_group")
CONSUMER_NAME = os.getenv("CONSUMER_NAME", socket.gethostname())
READ_COUNT = int(os.getenv("REDIS_READ_COUNT", "10"))
READ_BLOCK_MS = int(os.getenv("REDIS_BLOCK_MS", "5000"))

r = redis.Redis(
    host=os.getenv("REDIS_HOST"),
    port=int(os.getenv("REDIS_PORT")),
    decode_responses=True
)

conn = psycopg2.connect(
    dbname=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT")),
)

cur = conn.cursor()
cur.execute(
    """
    CREATE TABLE IF NOT EXISTS logs (
        id SERIAL PRIMARY KEY,
        message TEXT,
        timestamp FLOAT
    )
"""
)
conn.commit()


def listen():
    conn = psycopg2.connect(
        dbname=os.getenv("POSTGRES_DB"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT")),
    )
    cur = conn.cursor()

    try:
        r.xgroup_create(STREAM_NAME, GROUP_NAME, id="0", mkstream=True)
    except:
        pass

    while True:
        messages = r.xreadgroup(
            groupname=GROUP_NAME,
            consumername=CONSUMER_NAME,
            streams={STREAM_NAME: ">"},
            count=READ_COUNT,
            block=READ_BLOCK_MS
        )

        for stream, msgs in messages:
            for msg_id, data in msgs:
                cur.execute(
                    "INSERT INTO logs (message, timestamp) VALUES (%s, %s)",
                    (data["message"], float(data["timestamp"]))
                )
                conn.commit()

                r.xack(STREAM_NAME, GROUP_NAME, msg_id)
                print("Inserted:", data)

@app.on_event("startup")
def start_listener():
    global listener_thread
    if listener_thread is None or not listener_thread.is_alive():
        listener_thread = threading.Thread(target=listen, daemon=True)
        listener_thread.start()

@app.get("/")
def health():
    return {"status": "ok"}
