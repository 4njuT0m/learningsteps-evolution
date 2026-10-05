import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# The app reads DATABASE_URL when it is imported. The tests never connect to it.
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "api"))

from main import app  # noqa: E402
from routers.journal_router import get_entry_service  # noqa: E402
from services.entry_service import EntryService  # noqa: E402


class FakeDB:
    """Keeps entries in a dict instead of PostgreSQL."""

    def __init__(self):
        self.rows = {}

    async def create_entry(self, entry_data):
        self.rows[entry_data["id"]] = dict(entry_data)
        return dict(entry_data)

    async def get_all_entries(self):
        return [dict(row) for row in self.rows.values()]

    async def get_entry(self, entry_id):
        row = self.rows.get(entry_id)
        return dict(row) if row else None

    async def update_entry(self, entry_id, updated_data):
        self.rows[entry_id] = dict(updated_data)

    async def delete_entry(self, entry_id):
        self.rows.pop(entry_id, None)

    async def delete_all_entries(self):
        self.rows.clear()


@pytest.fixture
def client():
    db = FakeDB()

    async def fake_entry_service():
        yield EntryService(db)

    app.dependency_overrides[get_entry_service] = fake_entry_service
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()