from typing import AsyncGenerator
from fastapi import APIRouter, HTTPException, Depends
from repositories.postgres_repository import PostgresDB
from services.entry_service import EntryService
from models.entry import Entry, EntryCreate, EntryUpdate


router = APIRouter()

# TODO: Add authentication middleware
# TODO: Add request validation middleware
# TODO: Add rate limiting middleware
# TODO: Add API versioning
# TODO: Add response caching

async def get_entry_service() -> AsyncGenerator[EntryService, None]:
    async with PostgresDB() as db:
        yield EntryService(db)

@router.post("/entries")
async def create_entry(entry_data: EntryCreate, entry_service: EntryService = Depends(get_entry_service)):
    """Create a new journal entry."""
    try:
        # Create the full entry with auto-generated fields
        entry = Entry(
            work=entry_data.work,
            struggle=entry_data.struggle,
            intention=entry_data.intention
        )

        # Store the entry in the database
        created_entry = await entry_service.create_entry(entry.model_dump())

        # Return success response (FastAPI handles datetime serialization automatically)
        return {
            "detail": "Entry created successfully",
            "entry": created_entry
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating entry: {str(e)}")

# Implements GET /entries endpoint to list all journal entries
@router.get("/entries")
async def get_all_entries(entry_service: EntryService = Depends(get_entry_service)):
    """Get all journal entries."""
    result = await entry_service.get_all_entries()
    return {"entries": result, "count": len(result)}

@router.get("/entries/{entry_id}")
async def get_entry(entry_id: str, entry_service: EntryService = Depends(get_entry_service)):
    """Get a single journal entry by ID."""
    entry = await entry_service.get_entry(entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    return entry

@router.patch("/entries/{entry_id}")
async def update_entry(
    entry_id: str, entry_update: EntryUpdate, entry_service: EntryService = Depends(get_entry_service)
):
    """Update a journal entry. Only the fields that are sent are changed."""
    changes = entry_update.model_dump(exclude_unset=True, exclude_none=True)
    if not changes:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = await entry_service.update_entry(entry_id, changes)
    if not result:
        raise HTTPException(status_code=404, detail="Entry not found")
    return result

@router.delete("/entries/{entry_id}")
async def delete_entry(entry_id: str, entry_service: EntryService = Depends(get_entry_service)):
    """Delete a single journal entry by ID."""
    entry = await entry_service.get_entry(entry_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    await entry_service.delete_entry(entry_id)
    return {"detail": "Entry deleted"}

@router.delete("/entries")
async def delete_all_entries(entry_service: EntryService = Depends(get_entry_service)):
    """Delete all journal entries"""
    await entry_service.delete_all_entries()
    return {"detail": "All entries deleted"}