# backend/routers/analytics.py

from fastapi import APIRouter, Depends, HTTPException
import logging
from deps import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/analytics", tags=["Analytics"])


@router.get("/data")
async def get_analytics_data(db=Depends(get_db)):
    """Get analytics data"""
    try:
        return db.get_analytics_data()
    except Exception as e:
        logger.error(f"Error getting analytics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/approval-history")
async def get_approval_history(db=Depends(get_db)):
    """Get approval history"""
    try:
        return db.get_approval_history()
    except Exception as e:
        logger.error(f"Error getting approval history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/role-mapping")
async def get_role_mapping(db=Depends(get_db)):
    """Get role mapping data"""
    try:
        return db.get_role_mapping_data()
    except Exception as e:
        logger.error(f"Error getting role mapping: {e}")
        raise HTTPException(status_code=500, detail=str(e))
