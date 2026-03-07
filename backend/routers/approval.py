# backend/routers/approval.py

from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any
import logging
from deps import get_db
from models.purchase_request import ApproveRejectRequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/approval", tags=["Approval"])


@router.get("/batches")
async def get_batch_list(db=Depends(get_db)):
    """Get approval batch list"""
    try:
        return db.get_batch_list()
    except Exception as e:
        logger.error(f"Error getting batch list: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/batch/{batch_id}")
async def get_batch_detail(batch_id: str, db=Depends(get_db)):
    """Get batch detail"""
    try:
        return db.get_batch_detail(batch_id)
    except Exception as e:
        logger.error(f"Error getting batch detail: {e}")
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/batch/{batch_id}/status")
async def get_batch_status(batch_id: str, db=Depends(get_db)):
    """Get batch status"""
    try:
        return db.get_batch_status(batch_id)
    except Exception as e:
        logger.error(f"Error getting batch status: {e}")
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/batch/{batch_id}/summary")
async def get_batch_summary(batch_id: str, db=Depends(get_db)):
    """Get batch summary"""
    try:
        return db.get_batch_summary(batch_id)
    except Exception as e:
        logger.error(f"Error getting batch summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/approve/{batch_id}")
async def approve_batch(batch_id: str, data: Dict[str, Any], db=Depends(get_db)):
    """Approve batch"""
    try:
        return db.approve_batch(batch_id=batch_id, notes=data.get("notes"))
    except Exception as e:
        logger.error(f"Error approving batch: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/reject/{batch_id}")
async def reject_batch(batch_id: str, data: Dict[str, Any], db=Depends(get_db)):
    """Reject batch"""
    try:
        return db.reject_batch(batch_id=batch_id, reason=data.get("reason", "Rejected by approver"))
    except Exception as e:
        logger.error(f"Error rejecting batch: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========================================
# Approval History
# ========================================

@router.get("/history")
async def get_approval_history(db=Depends(get_db)):
    """Get approval history — PRs that have been Approved or Rejected"""
    try:
        return db.get_approval_history()
    except Exception as e:
        logger.error(f"Error getting approval history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ========================================
# NEW: Per-request approval endpoints
# ========================================

@router.get("/pending-requests")
async def get_pending_requests(db=Depends(get_db)):
    """Get all purchase requests with Pending status"""
    try:
        return db.get_purchase_requests_by_status(['Pending'])
    except Exception as e:
        logger.error(f"Error getting pending requests: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/approve-requests")
async def approve_requests(data: ApproveRejectRequest, db=Depends(get_db)):
    """Approve selected purchase requests"""
    try:
        if not data.request_ids:
            raise HTTPException(status_code=400, detail="No request IDs provided")
        return db.approve_purchase_requests(
            request_ids=data.request_ids,
            approver_id=data.approver_id
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error approving requests: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/reject-requests")
async def reject_requests(data: ApproveRejectRequest, db=Depends(get_db)):
    """Reject selected purchase requests with reason"""
    try:
        if not data.request_ids:
            raise HTTPException(status_code=400, detail="No request IDs provided")
        return db.reject_purchase_requests(
            request_ids=data.request_ids,
            approver_id=data.approver_id,
            reason=data.reason or "Rejected by approver"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error rejecting requests: {e}")
        raise HTTPException(status_code=500, detail=str(e))
