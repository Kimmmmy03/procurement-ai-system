# backend/routers/orders.py

from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List
import logging
from deps import get_db
from models.purchase_request import SubmitRequest
from models.inventory import AmendPORequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/orders", tags=["Orders"])


@router.get("/list")
async def get_purchase_orders(db=Depends(get_db)):
    """Get purchase orders list"""
    try:
        return db.get_purchase_orders()
    except Exception as e:
        logger.error(f"Error getting purchase orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detail/{po_id}")
async def get_purchase_order(po_id: int, db=Depends(get_db)):
    """Get purchase order detail by PO_ID"""
    try:
        return db.get_purchase_order_detail(po_id)
    except Exception as e:
        logger.error(f"Error getting PO detail: {e}")
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/generate/{request_id}")
async def generate_purchase_order(request_id: int, db=Depends(get_db)):
    """Generate a purchase order from an approved purchase request"""
    try:
        return db.generate_purchase_order(request_id)
    except Exception as e:
        logger.error(f"Error generating PO for request {request_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-grouped")
async def generate_grouped_purchase_orders(data: SubmitRequest, db=Depends(get_db)):
    """Generate POs from multiple approved requests, grouped by supplier"""
    try:
        if not data.request_ids:
            raise HTTPException(status_code=400, detail="No request IDs provided")
        return db.generate_grouped_purchase_orders(data.request_ids)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating grouped POs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/email-template/{po_id}")
async def get_email_template(po_id: int, template_type: str = "Standard", db=Depends(get_db)):
    """Get email template for PO"""
    try:
        return db.get_email_template(po_id, template_type)
    except Exception as e:
        logger.error(f"Error getting email template: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/send-email/{po_number}")
async def send_purchase_order_email(po_number: str, email_data: Dict[str, Any], db=Depends(get_db)):
    """Send purchase order email and mark PO as SENT"""
    try:
        result = db.send_purchase_order_email(po_number, email_data)
        # Mark PO as SENT after email is dispatched
        if result.get("success"):
            try:
                po_id = int(po_number.replace('PO-', ''))
            except (ValueError, AttributeError):
                po_id = po_number
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    UPDATE purchase_orders SET Status = 'SENT'
                    WHERE PO_ID = ? AND Status = 'DRAFT'
                ''', (po_id,))
        return result
    except Exception as e:
        logger.error(f"Error sending email: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── OA / Negotiation Endpoints ────────────────────────────────────

@router.post("/{po_id}/amend")
async def amend_purchase_order(po_id: int, data: AmendPORequest, db=Depends(get_db)):
    """Apply supplier counter-offer amendments to a PO.
    If confirmed_total_value exceeds original by >5%, auto-routes to PENDING_REAPPROVAL."""
    try:
        line_items = [li.model_dump() for li in data.line_items]
        result = db.amend_purchase_order(
            po_id=po_id,
            line_items=line_items,
            etd_date=data.etd_date,
            reason=data.reason,
        )
        if not result.get("success"):
            raise HTTPException(status_code=400, detail=result.get("error", "Amendment failed"))
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error amending PO {po_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{po_id}/confirm")
async def confirm_purchase_order(po_id: int, db=Depends(get_db)):
    """Lock and finalize PO — changes status to CONFIRMED."""
    try:
        result = db.confirm_purchase_order(po_id)
        if not result.get("success"):
            raise HTTPException(status_code=400, detail=result.get("error", "Confirmation failed"))
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error confirming PO {po_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{po_id}/reapprove")
async def approve_po_reapproval(po_id: int, db=Depends(get_db)):
    """Executive approves a PO that exceeded the 5% price variance threshold."""
    try:
        result = db.approve_po_reapproval(po_id)
        if not result.get("success"):
            raise HTTPException(status_code=400, detail=result.get("error", "Re-approval failed"))
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error re-approving PO {po_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{po_id}/complete")
async def mark_po_completed(po_id: int, db=Depends(get_db)):
    """Mark a confirmed PO as COMPLETED."""
    try:
        with db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE purchase_orders SET Status = 'COMPLETED'
                WHERE PO_ID = ? AND Status = 'CONFIRMED'
            ''', (po_id,))
            if cursor.rowcount == 0:
                raise HTTPException(status_code=400, detail="PO not found or not in CONFIRMED status")
        return {"success": True, "message": "PO marked as completed"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error completing PO {po_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{po_id}/revisions")
async def get_po_revisions(po_id: int, db=Depends(get_db)):
    """Get revision history for a PO."""
    try:
        return {"revisions": db.get_po_revision_history(po_id)}
    except Exception as e:
        logger.error(f"Error getting revisions for PO {po_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
