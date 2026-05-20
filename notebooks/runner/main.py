"""
Notebook Runner API
Exposes a REST interface for executing parametrized notebooks via Papermill.
Jobs are persisted in SQLite so state survives container restarts.
"""

from __future__ import annotations

import os
import threading
import uuid
from contextlib import contextmanager
from datetime import datetime
from typing import Any

import papermill as pm
from fastapi import BackgroundTasks, FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

app = FastAPI(title="Notebook Runner", version="1.1.0")

NOTEBOOKS_INPUT = os.getenv("NOTEBOOKS_INPUT", "/notebooks/input")
NOTEBOOKS_OUTPUT = os.getenv("NOTEBOOKS_OUTPUT", "/notebooks/output")
DB_PATH = os.getenv("RUNNER_DB_PATH", "/notebooks/db/jobs.db")

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

engine = create_engine(f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class JobRecord(Base):
    __tablename__ = "jobs"

    job_id = Column(String(36), primary_key=True)
    status = Column(String(16), nullable=False, default="running")
    notebook = Column(String(256), nullable=False)
    parameters = Column(Text, nullable=False, default="{}")
    output = Column(String(512), nullable=True)
    error = Column(Text, nullable=True)
    started_at = Column(DateTime, nullable=False)
    finished_at = Column(DateTime, nullable=True)


Base.metadata.create_all(engine)

_lock = threading.Lock()


@contextmanager
def get_db():
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _job_to_dict(job: JobRecord) -> dict:
    import json
    return {
        "job_id": job.job_id,
        "status": job.status,
        "notebook": job.notebook,
        "parameters": json.loads(job.parameters),
        "output": job.output,
        "error": job.error,
        "started_at": job.started_at.isoformat() if job.started_at else None,
        "finished_at": job.finished_at.isoformat() if job.finished_at else None,
    }


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class RunRequest(BaseModel):
    notebook: str
    parameters: dict[str, Any] = {}
    kernel_name: str = "python3"


class JobStatus(BaseModel):
    job_id: str
    status: str
    notebook: str
    parameters: dict[str, Any]
    output: str | None = None
    error: str | None = None
    started_at: str
    finished_at: str | None = None


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

def _execute(job_id: str, req: RunRequest) -> None:
    import json

    input_path = os.path.join(NOTEBOOKS_INPUT, req.notebook)
    nb_stem = os.path.basename(req.notebook).replace(".ipynb", "")
    ts = datetime.now().strftime("%Y%m%dT%H%M%S")
    output_path = os.path.join(NOTEBOOKS_OUTPUT, f"{nb_stem}__{ts}__{job_id[:8]}.ipynb")

    os.makedirs(NOTEBOOKS_OUTPUT, exist_ok=True)

    try:
        pm.execute_notebook(
            input_path=input_path,
            output_path=output_path,
            parameters=req.parameters,
            kernel_name=req.kernel_name,
            progress_bar=False,
        )
        with _lock, get_db() as db:
            job = db.get(JobRecord, job_id)
            job.status = "success"
            job.output = output_path
            job.finished_at = datetime.now()
    except Exception as exc:
        with _lock, get_db() as db:
            job = db.get(JobRecord, job_id)
            job.status = "failed"
            job.error = str(exc)
            job.output = output_path if os.path.exists(output_path) else None
            job.finished_at = datetime.now()


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/run", response_model=JobStatus, status_code=202)
async def run_notebook(req: RunRequest, background_tasks: BackgroundTasks) -> dict:
    import json

    input_path = os.path.join(NOTEBOOKS_INPUT, req.notebook)
    if not os.path.exists(input_path):
        raise HTTPException(status_code=404, detail=f"Notebook not found: {req.notebook}")

    job_id = str(uuid.uuid4())
    now = datetime.now()

    with _lock, get_db() as db:
        db.add(JobRecord(
            job_id=job_id,
            status="running",
            notebook=req.notebook,
            parameters=json.dumps(req.parameters),
            started_at=now,
        ))

    background_tasks.add_task(_execute, job_id, req)

    return {
        "job_id": job_id,
        "status": "running",
        "notebook": req.notebook,
        "parameters": req.parameters,
        "output": None,
        "error": None,
        "started_at": now.isoformat(),
        "finished_at": None,
    }


@app.get("/status/{job_id}", response_model=JobStatus)
async def get_status(job_id: str) -> dict:
    with get_db() as db:
        job = db.get(JobRecord, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return _job_to_dict(job)


@app.get("/jobs")
async def list_jobs() -> list[dict]:
    with get_db() as db:
        jobs = db.query(JobRecord).order_by(JobRecord.started_at.desc()).all()
        return [_job_to_dict(j) for j in jobs]


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "notebooks_input": NOTEBOOKS_INPUT,
        "notebooks_output": NOTEBOOKS_OUTPUT,
        "db_path": DB_PATH,
    }
