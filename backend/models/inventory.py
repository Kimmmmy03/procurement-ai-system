# backend/models/inventory.py
"""Pydantic models for Inventory Segmentation, Item Lifecycle, and Shipping"""

from enum import Enum
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ── Enums ────────────────────────────────────────────────────────────

class LifecycleStatus(str, Enum):
    ACTIVE = "ACTIVE"
    PHASING_OUT = "PHASING_OUT"
    DISCONTINUED = "DISCONTINUED"
    NEW = "NEW"


class DemandType(str, Enum):
    STANDARD_STOCK = "STANDARD_STOCK"
    CUSTOMER_INDENT = "CUSTOMER_INDENT"
    NEW_PRODUCT = "NEW_PRODUCT"


class POStatus(str, Enum):
    DRAFT = "DRAFT"
    SENT = "SENT"
    NEGOTIATING = "NEGOTIATING"
    PENDING_REAPPROVAL = "PENDING_REAPPROVAL"
    CONFIRMED = "CONFIRMED"
    PENDING_ETD = "PENDING_ETD"
    IN_TRANSIT = "IN_TRANSIT"
    ARRIVED = "ARRIVED"
    COMPLETED = "COMPLETED"


class ShippingDocType(str, Enum):
    INVOICE = "Invoice"
    PACKING_LIST = "Packing List"
    MDA_PERMIT = "MDA Permit"
    BILL_OF_LADING = "Bill of Lading"
    OTHER = "Other"


# ── Inventory Segmentation ──────────────────────────────────────────

class InventorySegment(BaseModel):
    """Breakdown of a SKU's stock across channels and holds."""
    sku: str
    sellable_main_warehouse: int = 0
    sellable_tiktok: int = 0
    sellable_shopee: int = 0
    sellable_lazada: int = 0
    reserved_b2b_projects: int = 0
    quarantine_sirim: int = 0
    quarantine_rework: int = 0

    @property
    def total_sellable(self) -> int:
        return (self.sellable_main_warehouse + self.sellable_tiktok
                + self.sellable_shopee + self.sellable_lazada)

    @property
    def total_reserved(self) -> int:
        return self.reserved_b2b_projects

    @property
    def total_quarantine(self) -> int:
        return self.quarantine_sirim + self.quarantine_rework

    @property
    def free_stock(self) -> int:
        """True availability = sellable - reserved (quarantine excluded)."""
        return self.total_sellable - self.reserved_b2b_projects


# ── Incoming Shipments (linked to active POs) ───────────────────────

class IncomingShipment(BaseModel):
    """A single incoming PO line relevant to a SKU."""
    po_id: int
    po_ref: str
    sku: str
    qty: int
    eta_date: Optional[str] = None
    supplier_confirmed: bool = False
    po_status: str = "PENDING_ETD"


# ── Shipping Documents ──────────────────────────────────────────────

class ShippingDocument(BaseModel):
    """A document attached to a purchase order."""
    id: Optional[int] = None
    po_id: int
    doc_type: str  # ShippingDocType value
    file_url: str
    uploaded_at: Optional[str] = None


class ShippingDocUploadRequest(BaseModel):
    doc_type: str
    file_url: str


# ── ETD Confirmation ────────────────────────────────────────────────

class ConfirmETDRequest(BaseModel):
    etd_date: str  # ISO date string e.g. "2026-04-15"


# ── Extended Item (returned by detail APIs) ─────────────────────────

class ItemExtended(BaseModel):
    """Full item view with lifecycle, segmented inventory, and pipeline."""
    sku: str
    product: str
    category: str
    lifecycle_status: str = "ACTIVE"
    demand_type: str = "STANDARD_STOCK"
    unit_price: float = 0.0
    supplier: Optional[str] = None
    lead_time_days: int = 14
    moq: int = 1
    inventory: Optional[InventorySegment] = None
    incoming_shipments: List[IncomingShipment] = []
    current_stock: int = 0  # legacy flat field, kept for backward compat


# ── Xeersoft Data Ingestion Models ──────────────────────────────────

class XeersoftItemRecord(BaseModel):
    """A single cleaned item record from Xeersoft inventory data."""
    sku: str
    product_name: str
    category: Optional[str] = None
    warehouse_main: int = 0
    tiktok_shop: int = 0
    lazada: int = 0
    shopee: int = 0
    sirim_quarantine: int = 0
    rework: int = 0
    annotations: Optional[str] = None
    monthly_sales: dict = {}  # {month_key: qty}


class XeersoftUploadResponse(BaseModel):
    """Response from Xeersoft inventory upload."""
    success: bool
    filename: str
    items_processed: int
    items_skipped: int
    items_upserted: int
    sales_months_ingested: int
    annotations_extracted: int
    preview: List[dict] = []


# ── PO Negotiation Models ──────────────────────────────────────────

class POLineItemAmendment(BaseModel):
    """A single line item amendment from the supplier's counter-offer."""
    request_id: int
    confirmed_qty: int
    confirmed_price: float


class AmendPORequest(BaseModel):
    """Request body for amending a PO with supplier counter-offer."""
    line_items: List[POLineItemAmendment]
    etd_date: Optional[str] = None
    reason: Optional[str] = None


class PORevisionHistory(BaseModel):
    """Audit trail entry for a PO change."""
    id: Optional[int] = None
    po_id: int
    changed_by: str
    timestamp: Optional[str] = None
    field_name: str
    previous_value: Optional[str] = None
    new_value: Optional[str] = None
    reason: Optional[str] = None
