# backend/routers/purchase_requests.py

from fastapi import APIRouter, Depends, HTTPException
from typing import Optional, Dict, Any
import logging
from deps import get_db
from models.purchase_request import OverrideRequest, SubmitRequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/purchase-requests", tags=["Purchase Requests"])


@router.get("/list")
async def get_purchase_requests(
    risk_level: Optional[str] = None,
    category: Optional[str] = None,
    status: Optional[str] = None,
    db=Depends(get_db)
):
    """Get purchase requests list with optional filters"""
    try:
        return db.get_purchase_requests(risk_level, category, status=status)
    except Exception as e:
        logger.error(f"Error getting purchase requests: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/by-status")
async def get_prs_by_status(statuses: str, db=Depends(get_db)):
    """Get purchase requests filtered by comma-separated status values"""
    try:
        status_list = [s.strip() for s in statuses.split(',')]
        return db.get_purchase_requests_by_status(status_list)
    except Exception as e:
        logger.error(f"Error getting PRs by status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detail/{request_id}")
async def get_purchase_request_detail(request_id: int, db=Depends(get_db)):
    """Get purchase request detail by RequestID"""
    try:
        return db.get_purchase_request_detail(request_id)
    except Exception as e:
        logger.error(f"Error getting PR detail for {request_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/override")
async def override_recommendation(data: OverrideRequest, db=Depends(get_db)):
    """Override AI recommendation with user quantity and reason"""
    try:
        return db.override_recommendation(
            request_id=data.request_id,
            quantity=data.quantity,
            reason_category=data.reason_category,
            additional_details=data.additional_details
        )
    except Exception as e:
        logger.error(f"Error overriding recommendation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/accept-all")
async def accept_all_recommendations(data: Dict[str, Any], db=Depends(get_db)):
    """Accept all AI recommendations"""
    try:
        return db.accept_all_recommendations(risk_levels=data.get("risk_levels"))
    except Exception as e:
        logger.error(f"Error accepting recommendations: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/submit")
async def submit_for_approval(data: SubmitRequest, db=Depends(get_db)):
    """Submit selected PRs for approval (Draft → Pending)"""
    try:
        if not data.request_ids:
            raise HTTPException(status_code=400, detail="No request IDs provided")
        return db.submit_for_approval(data.request_ids)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting for approval: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save-forecast")
async def save_forecast_results(data: Dict[str, Any], db=Depends(get_db)):
    """Save AI forecast results as Draft purchase requests"""
    try:
        logger.info(f"save-forecast endpoint called, db type: {type(db).__name__}")
        result = db.save_forecast_as_purchase_requests(data.get("workflow_result", {}))
        logger.info(f"save-forecast result: inserted_count={result.get('inserted_count')}")
        return result
    except Exception as e:
        logger.error(f"Error saving forecast results: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
