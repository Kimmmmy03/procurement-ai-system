# backend/routers/suppliers.py

from fastapi import APIRouter, Depends, HTTPException
import logging
from deps import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/suppliers", tags=["Suppliers"])


@router.get("/list")
async def get_all_suppliers(db=Depends(get_db)):
    """Get all suppliers with their item counts and details"""
    try:
        return db.get_all_suppliers()
    except Exception as e:
        logger.error(f"Error getting suppliers: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detail/{supplier_id}")
async def get_supplier_detail(supplier_id: int, db=Depends(get_db)):
    """Get supplier detail with all their items from vendor_master"""
    try:
        return db.get_supplier_detail(supplier_id)
    except Exception as e:
        logger.error(f"Error getting supplier detail: {e}")
        raise HTTPException(status_code=500, detail=str(e))
