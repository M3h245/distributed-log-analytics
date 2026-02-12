from fastapi import FastAPI, Query
import time
import redis
import os

app = FastAPI()

STREAM_NAME = os.getenv("REDIS_STREAM", "log_stream")
DEFAULT_MESSAGE = os.getenv("DEFAULT_LOG_MESSAGE", "log event")

r = redis.Redis(
    host=os.getenv("REDIS_HOST"),
    port=int(os.getenv("REDIS_PORT")),
    decode_responses=True
)


@app.get("/")
def health():
    return {"status": "ok"}


@app.get("/send")
def send_event(message: str = Query(default=DEFAULT_MESSAGE)):
    data = {"message": message, "timestamp": time.time()}
    message_id = r.xadd(STREAM_NAME, data)
    return {"status": "sent", "stream": STREAM_NAME, "id": message_id, "event": data}
