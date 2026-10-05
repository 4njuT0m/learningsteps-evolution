import logging
from contextlib import asynccontextmanager

import asyncpg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse

from repositories.postgres_repository import DATABASE_URL
from routers.journal_router import router as journal_router

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("learningsteps")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("LearningSteps API started")
    yield
    logger.info("LearningSteps API stopped")


app = FastAPI(
    title="LearningSteps API",
    description="A simple learning journal API for tracking daily work, struggles, and intentions",
    lifespan=lifespan,
)
app.include_router(journal_router)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["health"])
def health():
    """The API process is running. Used by Kubernetes to restart a stuck container."""
    return {"status": "ok"}


@app.get("/health/db", tags=["health"])
async def health_db():
    """The API can reach the database. Used by Kubernetes to send traffic only to ready pods."""
    try:
        conn = await asyncpg.connect(DATABASE_URL, timeout=3)
        try:
            await conn.fetchval("SELECT 1")
        finally:
            await conn.close()
    except Exception:
        logger.exception("Database health check failed")
        raise HTTPException(status_code=503, detail="Database not reachable")
    return {"status": "ok", "database": "reachable"}