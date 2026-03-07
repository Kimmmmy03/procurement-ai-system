# backend/xeersoft_ingestion.py
"""
Xeersoft Inventory Data Ingestion Pipeline.

Handles cleaning, annotation extraction, and transformation of
Xeersoft-format Excel files into normalised database records.
"""

import re
import logging
import pandas as pd
from typing import Dict, Any, List, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)


# ── Regex-based numeric cleaning ──────────────────────────────────

_BRACKET_RE = re.compile(r'\[(.+?)\]')
_NUM_RE = re.compile(r'^[-+]?\d*\.?\d+')
_SUPPLIER_PREFIX_RE = re.compile(r'^([A-Za-z]+\d+)')
_SUPPLIER_LETTERS_RE = re.compile(r'^([A-Za-z]+)')


def extract_supplier_code(item_code: str) -> str:
    """Extract supplier code from the alphanumeric prefix of an Item Code.

    Takes the portion before the first hyphen, or the leading letters+digits block.

    Examples:
        'TAE11-005T'     -> 'TAE11'
        'TAE11-M310/XR'  -> 'TAE11'
        'PKG01-BX01'     -> 'PKG01'
        'SPR01-FL01'     -> 'SPR01'
        'SKU-E001'       -> 'SKU'
        '12345'          -> ''
    """
    code = item_code.strip()
    # Try prefix before first hyphen (e.g. TAE11-005T -> TAE11)
    if '-' in code:
        prefix = code.split('-')[0].strip()
        if prefix:
            return prefix.upper()
    # Fallback: letters+digits block (e.g. HM5020 -> HM5020)
    m = _SUPPLIER_PREFIX_RE.match(code)
    if m:
        return m.group(1).upper()
    # Last fallback: letters only
    m = _SUPPLIER_LETTERS_RE.match(code)
    return m.group(1).upper() if m else ''


def extract_numeric_and_annotation(value) -> Tuple[float, str]:
    """Extract leading numeric value and bracketed annotation from a cell.

    Examples:
        330                     -> (330.0, "")
        "330 [special promo]"   -> (330.0, "special promo")
        NaN / None / ""         -> (0.0, "")
        "just text"             -> (0.0, "just text")
    """
    if pd.isna(value):
        return 0.0, ""

    s = str(value).strip()
    if not s:
        return 0.0, ""

    # Extract annotation inside brackets
    annotation = ""
    bracket_match = _BRACKET_RE.search(s)
    if bracket_match:
        annotation = bracket_match.group(1).strip()

    # Extract leading number
    num_match = _NUM_RE.match(s)
    if num_match:
        return float(num_match.group()), annotation

    # Pure text (no leading number)
    return 0.0, annotation or s


def clean_numeric(value) -> int:
    """Extract integer value from a cell, ignoring annotations."""
    num, _ = extract_numeric_and_annotation(value)
    return int(num)


# ── Column mapping constants ─────────────────────────────────────

INVENTORY_COL_MAP = {
    'BR-NM': 'sellable_main_warehouse',
    'BR-NM6 (TikTok)': 'sellable_tiktok',
    'BR-NM8 (Lazada)': 'sellable_lazada',
    'BR-NM9 (Shopee)': 'sellable_shopee',
    'BR-NM10 (e-store)': 'sellable_estore',
    'BR-NM1 (Project)': 'reserved_b2b_projects',
    'BR-NM2 (Corporate)': 'sellable_corporate',
    'BR-NM3 (East Mas)': 'sellable_east_mas',
    'BR-NM11 (minor BP)': 'sellable_minor_bp',
    'BR-RW (rework)': 'quarantine_rework',
    'BR-BP': 'stock_bp',
    'BR-DM': 'stock_dm',
    'BR-INC (SIRIM)': 'quarantine_sirim',
    'BR-INC2 (incomplete)': 'quarantine_incomplete',
    'MGIT': 'stock_mgit',
}

EXTRA_INVENTORY_COLS = {}


# ── Main processing pipeline ─────────────────────────────────────

def process_xeersoft_dataframe(df: pd.DataFrame) -> Dict[str, Any]:
    """Process a raw Xeersoft inventory DataFrame into clean records.

    Returns dict with keys:
        items          - list of item dicts for items table
        inventory      - list of inventory segment dicts
        monthly_sales  - list of (sku, year, month, qty) tuples
        annotations    - list of {sku, column, annotation} dicts
        skipped        - list of skipped row reasons
    """
    items = []
    inventory_records = []
    monthly_sales = []
    annotations = []
    skipped = []

    # Identify date columns (datetime objects in column names)
    date_columns = []
    for col in df.columns:
        if isinstance(col, datetime):
            date_columns.append(col)

    # Also check for the "as @ ..." column which represents current month sales
    current_month_col = None
    for col in df.columns:
        if isinstance(col, str) and col.startswith('as @'):
            current_month_col = col
            break

    logger.info(f"Found {len(date_columns)} date columns for monthly sales history")

    current_category = None

    for idx, row in df.iterrows():
        sku = str(row.get('Item Code', '')).strip()
        model = row.get('MODEL')

        # Category header rows have no MODEL
        if pd.isna(model) or str(model).strip() == '':
            current_category = sku if sku else current_category
            skipped.append(f"Row {idx}: category header '{sku}'")
            continue

        if not sku:
            skipped.append(f"Row {idx}: empty SKU")
            continue

        product_name = str(model).strip()

        # ── Collect annotations from all columns ──
        row_annotations = []
        for col in list(INVENTORY_COL_MAP.keys()) + list(EXTRA_INVENTORY_COLS.keys()) + date_columns:
            if col in df.columns:
                _, ann = extract_numeric_and_annotation(row.get(col))
                if ann:
                    col_label = col.strftime('%Y-%m') if isinstance(col, datetime) else str(col)
                    row_annotations.append(f"{col_label}: {ann}")
                    annotations.append({
                        'sku': sku,
                        'column': col_label,
                        'annotation': ann,
                    })

        annotation_text = '; '.join(row_annotations) if row_annotations else None

        # ── Item record ──
        # Calculate sales from available data
        sales_30 = 0
        sales_60 = 0
        sales_90 = 0
        sorted_dates = sorted(date_columns, reverse=True)
        for i, dt in enumerate(sorted_dates):
            val = clean_numeric(row.get(dt, 0))
            if i < 1:
                sales_30 += val
            if i < 2:
                sales_60 += val
            if i < 3:
                sales_90 += val

        # Calculate total stock in hand
        warehouse_main = clean_numeric(row.get('BR-NM', 0))
        total_stock = warehouse_main
        for col in ['BR-NM6 (TikTok)', 'BR-NM8 (Lazada)', 'BR-NM9 (Shopee)']:
            if col in df.columns:
                total_stock += clean_numeric(row.get(col, 0))

        supplier_code = extract_supplier_code(sku)

        # Xeersoft only provides stock & sales data.
        # Supplier-enriched fields (unit_price, supplier, lead_time_days, moq,
        # failure_rate, lifecycle_status, demand_type, units_per_ctn, cbm_per_ctn,
        # weight_per_ctn) are left None and populated when vendor master is uploaded.
        items.append({
            'sku': sku,
            'product': product_name,
            'category': current_category or 'General',
            'current_stock': total_stock,
            'sales_last_30_days': sales_30,
            'sales_last_60_days': sales_60,
            'sales_last_90_days': sales_90,
            'unit_price': None,
            'supplier': None,
            'lead_time_days': None,
            'moq': None,
            'failure_rate': None,
            'lifecycle_status': None,
            'demand_type': None,
            'annotations': annotation_text,
            'supplier_code': supplier_code,
            'units_per_ctn': None,
            'cbm_per_ctn': None,
            'weight_per_ctn': None,
        })

        # ── Inventory segment record ──
        inv = {'sku': sku, 'supplier_code': supplier_code}
        for src_col, dest_col in INVENTORY_COL_MAP.items():
            if src_col in df.columns:
                inv[dest_col] = clean_numeric(row.get(src_col, 0))
            else:
                inv[dest_col] = 0
        for src_col, dest_col in EXTRA_INVENTORY_COLS.items():
            if src_col in df.columns:
                inv[dest_col] = clean_numeric(row.get(src_col, 0))
            else:
                inv[dest_col] = 0
        inventory_records.append(inv)

        # ── Monthly sales history (wide -> long) ──
        for dt_col in date_columns:
            val = clean_numeric(row.get(dt_col, 0))
            year = dt_col.year
            month = dt_col.month
            monthly_sales.append((sku, year, month, val))

        # Also capture current month column if present
        if current_month_col and current_month_col in df.columns:
            val = clean_numeric(row.get(current_month_col, 0))
            now = datetime.now()
            monthly_sales.append((sku, now.year, now.month, val))

    return {
        'items': items,
        'inventory': inventory_records,
        'monthly_sales': monthly_sales,
        'annotations': annotations,
        'skipped': skipped,
    }
