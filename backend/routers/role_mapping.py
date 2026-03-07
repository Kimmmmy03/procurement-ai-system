# backend/routers/role_mapping.py

from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any
import logging
from deps import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/role-mapping", tags=["Role Mapping"])


@router.get("/data")
async def get_role_mapping_data(db=Depends(get_db)):
    """Get role mapping data from procurement_users table"""
    try:
        return db.get_role_mapping_data()
    except Exception as e:
        logger.error(f"Error getting role mapping data: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/update")
async def update_role_assignment(data: Dict[str, Any], db=Depends(get_db)):
    """Update role assignment — add/remove category or update approval limit"""
    try:
        return db.update_role_assignment(
            officer_id=data.get("officer_id"),
            category=data.get("category"),
            action=data.get("action"),
            approval_limit=data.get("approval_limit"),
        )
    except Exception as e:
        logger.error(f"Error updating role: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/assign-supervisor")
async def assign_supervisor(data: Dict[str, Any], db=Depends(get_db)):
    """Reassign an officer to a different supervisor (GM/MD)"""
    try:
        return db.assign_supervisor(
            officer_id=data.get("officer_id"),
            supervisor_id=data.get("supervisor_id"),
        )
    except Exception as e:
        logger.error(f"Error assigning supervisor: {e}")
        raise HTTPException(status_code=500, detail=str(e))


