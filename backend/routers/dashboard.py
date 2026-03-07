# backend/routers/dashboard.py

from fastapi import APIRouter, Depends
import logging
from deps import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])


@router.get("/officer")
async def get_officer_dashboard(db=Depends(get_db)):
    """Get officer dashboard data"""
    try:
        return db.get_officer_dashboard()
    except Exception as e:
        logger.error(f"Error loading officer dashboard: {e}")
        raise


@router.get("/approver")
async def get_approver_dashboard(db=Depends(get_db)):
    """Get approver dashboard data"""
    try:
        return db.get_approver_dashboard()
    except Exception as e:
        logger.error(f"Error loading approver dashboard: {e}")
        raise
