# backend/models/purchase_request.py
"""Pydantic models for Purchase Request endpoints"""

from pydantic import BaseModel
from typing import Optional, List, Dict


class OverrideRequest(BaseModel):
    request_id: int
    quantity: int
    reason_category: str
    additional_details: Optional[str] = None


class SubmitRequest(BaseModel):
    request_ids: List[int]


class ApproveRejectRequest(BaseModel):
    request_ids: List[int]
    approver_id: int = 2
    reason: Optional[str] = None


class PurchaseRequestDetail(BaseModel):
    """Represents a single AI-recommended purchase request with manufacturing logistics data."""
    sku: str
    supplier_name: str
    product_name: Optional[str] = None
    final_qty: int  # Replaces recommended_qty
    total_cbm: float
    container_strategy: str  # "Full Container Load", "Less than Container Load", or "Local Bulk"
    container_fill_rate_percentage: int
    estimated_transit_days: int
    stock_coverage_days: int
    risk_level: str  # "High", "Medium", "Low"
    ai_reasoning: str
    unit_price: Optional[float] = 0.0
    total_value: Optional[float] = 0.0


class BatchSummaryResponse(BaseModel):
    """Aggregated cockpit metrics for a batch of purchase requests."""
    batch_id: str
    total_items: int
    total_value: float
    avg_stock_coverage_days: int
    high_risk_items_count: int
    container_breakdown: Dict[str, int]  # e.g., {"Full Container Load": 2, "Less than Container Load": 1}


class SupplierUploadResponse(BaseModel):
    """Response from supplier master list upload."""
    success: bool
    filename: str
    rows_processed: int
    suppliers_added: int
    suppliers_updated: int
    rows_skipped: int
    preview: List[Dict]
    skipped_reasons: List[str] = []
