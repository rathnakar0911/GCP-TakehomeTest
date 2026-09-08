import json
import logging
import os
import time
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse

app = FastAPI(title="Assessment App B")
logger = logging.getLogger("app-b")
logger.setLevel(logging.INFO)

APP_NAME = os.getenv("APP_NAME", "app-b")
CLUSTER_NAME = os.getenv("CLUSTER_NAME", "unknown")
POD_NAME = os.getenv("HOSTNAME", "unknown")


def emit(level: str, endpoint: str, status: int, latency_ms: int, message: str):
    record = {
        "severity": level,
        "application": APP_NAME,
        "cluster": CLUSTER_NAME,
        "pod": POD_NAME,
        "endpoint": endpoint,
        "http_status": status,
        "latency_ms": latency_ms,
        "message": message,
    }
    print(json.dumps(record), flush=True)


@app.get("/api/app-b/hello")
def hello():
    start = time.perf_counter()
    response = {"application": APP_NAME, "cluster": CLUSTER_NAME, "pod": POD_NAME,
                "message": "Hello from Application B"}
    emit("INFO", "/api/app-b/hello", 200, int((time.perf_counter() - start) * 1000), "request completed")
    return response


@app.get("/")
def root():
    return {"status": "UP", "application": APP_NAME}


@app.get("/api/app-b/health")
def health():
    return {"status": "UP", "application": APP_NAME, "cluster": CLUSTER_NAME}


@app.get("/api/app-b/work")
def work(delay: int = Query(100, ge=0, le=5000)):
    start = time.perf_counter()
    time.sleep(delay / 1000)
    latency = int((time.perf_counter() - start) * 1000)
    emit("INFO", "/api/app-b/work", 200, latency, "work completed")
    return {"application": APP_NAME, "cluster": CLUSTER_NAME, "delay_ms": delay, "latency_ms": latency}


@app.get("/api/app-b/error")
def error():
    emit("ERROR", "/api/app-b/error", 500, 0, "intentional assessment error")
    return JSONResponse(status_code=500, content={"error": "intentional assessment error"})
