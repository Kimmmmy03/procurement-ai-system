# backend/routers/custom_seasonality.py

"""
CRUD endpoints for seasonality events (system + custom).
Events are stored in [dbo].[seasonality_events] with is_system flag.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from deps import get_db
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/seasonality", tags=["Seasonality Events"])


class SeasonalityEventIn(BaseModel):
    id: Optional[int] = None
    name: str
    description: Optional[str] = ""
    months: List[int]           # 1=Jan .. 12=Dec
    multiplier: float = 1.2
    category: str = "festive"
    severity: str = "medium"


@router.get("/events")
async def list_events(db=Depends(get_db)):
    """Return all seasonality events (system + custom)."""
    try:
        events = db.get_seasonality_events()
        return {"events": events}
    except Exception as e:
        logger.error(f"Error fetching seasonality events: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/events")
async def upsert_event(event: SeasonalityEventIn, db=Depends(get_db)):
    """Create or update a seasonality event."""
    try:
        result = db.upsert_seasonality_event(event.model_dump())
        return {"success": True, "event_id": result.get("id")}
    except Exception as e:
        logger.error(f"Error upserting seasonality event: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/events/{event_id}")
async def delete_event(event_id: int, db=Depends(get_db)):
    """Delete a seasonality event by ID."""
    try:
        db.delete_seasonality_event(event_id)
        return {"success": True}
    except Exception as e:
        logger.error(f"Error deleting seasonality event {event_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
