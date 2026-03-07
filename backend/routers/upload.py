# backend/routers/upload.py

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
import logging
import io
import os
from deps import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/upload", tags=["Upload"])


def _parse_po_pdf(contents: bytes) -> list:
    """Extract line items from a purchase order PDF.

    Strategy:
    1. pdfplumber extract_tables() — works for PDFs with bordered/lined tables
    2. pdfplumber with relaxed table settings — catches tables without full borders
    3. pdfplumber text extraction — parses all text and returns structured data
    """
    import re

    # ── Attempt 1: pdfplumber table extraction ──────────────────────────────
    try:
        import pdfplumber

        all_tables_items = []
        with pdfplumber.open(io.BytesIO(contents)) as pdf:
            for page in pdf.pages:
                # Try default table extraction first
                tables = page.extract_tables()

                # If no tables found, try with relaxed settings
                if not tables:
                    tables = page.extract_tables({
                        "vertical_strategy": "text",
                        "horizontal_strategy": "text",
                        "snap_tolerance": 5,
                    })

                for table in tables:
                    if not table or len(table) < 2:
                        continue
                    # Use first row as headers
                    raw_headers = table[0]
                    headers = []
                    for i, h in enumerate(raw_headers):
                        if h and str(h).strip():
                            headers.append(str(h).strip().lower().replace(' ', '_').replace('\n', '_'))
                        else:
                            headers.append(f'col_{i}')

                    for row in table[1:]:
                        if not row or all(cell is None or str(cell).strip() == '' for cell in row):
                            continue
                        item = {}
                        for j, cell in enumerate(row):
                            key = headers[j] if j < len(headers) else f'col_{j}'
                            item[key] = str(cell).strip() if cell else ''
                        # Skip rows that look like headers or totals
                        vals = list(item.values())
                        text_joined = ' '.join(vals).lower()
                        if any(kw in text_joined for kw in ['total', 'subtotal', 'grand total', 'page ']):
                            continue
                        all_tables_items.append(item)

            if all_tables_items:
                logger.info(f"pdfplumber tables: extracted {len(all_tables_items)} rows")
                return all_tables_items

            # ── Attempt 2: Full text extraction from pdfplumber ─────────────
            full_text = ''
            with pdfplumber.open(io.BytesIO(contents)) as pdf:
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        full_text += text + '\n'

            if full_text.strip():
                return _parse_po_text(full_text)

    except ImportError:
        logger.warning("pdfplumber not installed, trying PyPDF2")
    except Exception as e:
        logger.warning(f"pdfplumber extraction failed: {e}", exc_info=True)

    # ── Attempt 3: PyPDF2 text extraction ───────────────────────────────────
    try:
        from PyPDF2 import PdfReader
        reader = PdfReader(io.BytesIO(contents))
        full_text = ''
        for page in reader.pages:
            text = page.extract_text()
            if text:
                full_text += text + '\n'

        if full_text.strip():
            return _parse_po_text(full_text)
    except Exception as e:
        logger.warning(f"PyPDF2 extraction failed: {e}")

    return []


def _parse_po_text(full_text: str) -> list:
    """Parse extracted PDF text into structured line items.

    Looks for lines that contain item codes, quantities, prices, etc.
    Returns raw text lines with metadata if no structured pattern is detected.
    """
    import re
    lines = [l.strip() for l in full_text.split('\n') if l.strip()]
    items = []

    # Try to detect item-like lines: lines containing numbers that look like qty/price
    # Common PO patterns: item_code, description, qty, unit_price, total
    number_pattern = re.compile(r'\d+[\.,]?\d*')
    item_code_pattern = re.compile(r'^[A-Z0-9][\w\-]{2,}', re.IGNORECASE)

    # First pass: try to find a header line to understand column layout
    header_idx = -1
    header_keywords = ['item', 'description', 'qty', 'quantity', 'price', 'amount',
                       'unit', 'total', 'no.', 'no', 'code', 'sku', 'product',
                       'model', 'part']
    for i, line in enumerate(lines):
        words_lower = line.lower()
        matches = sum(1 for kw in header_keywords if kw in words_lower)
        if matches >= 3:
            header_idx = i
            break

    if header_idx >= 0:
        # Found a header — return header + subsequent data lines
        header_line = lines[header_idx]
        for line in lines[header_idx + 1:]:
            # Skip empty-looking or total lines
            lower = line.lower()
            if any(kw in lower for kw in ['total', 'subtotal', 'grand total',
                                           'terms', 'payment', 'bank',
                                           'note:', 'remark', 'prepared by',
                                           'authorized', 'signature', 'thank you']):
                continue
            # Include lines that have at least one number (qty/price)
            if number_pattern.search(line):
                items.append({'line_data': line})
    else:
        # No clear header — return all substantive lines
        for line in lines:
            lower = line.lower()
            if any(kw in lower for kw in ['purchase order', 'page ', 'date:',
                                           'tel:', 'fax:', 'email:', 'address',
                                           'terms', 'payment', 'bank',
                                           'prepared by', 'authorized',
                                           'signature', 'thank you', 'note:']):
                continue
            if len(line) > 5:
                items.append({'line_data': line})

    logger.info(f"Text parser: extracted {len(items)} data lines from PDF text")
    return items

# Template directory — resolve relative to this file's location
_TEMPLATE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'template')

_TEMPLATE_MAP = {
    'xeersoft': 'Summary of Stock Movement on Weekly.xlsx',
    'supplier': 'vendor_master.xlsx',
}


@router.get("/template/{template_name}")
async def download_template(template_name: str):
    """Serve a pre-built Excel template file for download."""
    filename = _TEMPLATE_MAP.get(template_name.lower())
    if not filename:
        raise HTTPException(status_code=404, detail=f"Template '{template_name}' not found. Valid names: {list(_TEMPLATE_MAP.keys())}")
    filepath = os.path.join(_TEMPLATE_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail=f"Template file not found on server: {filename}")
    return FileResponse(
        path=filepath,
        filename=filename,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    )


@router.post("/purchase-order")
async def upload_purchase_order(file: UploadFile = File(...), db=Depends(get_db)):
    """Upload purchase order PDF file and extract line items."""
    try:
        contents = await file.read()
        logger.info(f"Uploaded file: {file.filename} ({len(contents)} bytes)")

        filename_lower = (file.filename or '').lower()

        items = []

        if filename_lower.endswith('.pdf'):
            items = _parse_po_pdf(contents)
        else:
            # Fallback: try pandas for Excel/CSV
            try:
                import pandas as pd
                if filename_lower.endswith('.csv'):
                    df = pd.read_csv(io.BytesIO(contents))
                else:
                    df = pd.read_excel(io.BytesIO(contents))
                for _, row in df.iterrows():
                    items.append(dict(row))
            except Exception as parse_err:
                logger.warning(f"Could not parse file: {parse_err}")

        return {
            "success": True,
            "filename": file.filename,
            "size": len(contents),
            "message": "File uploaded successfully",
            "items_detected": len(items),
            "matched_items": len(items),
            "unmatched_items": 0,
            "preview": items
        }
    except Exception as e:
        logger.error(f"Purchase order upload error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/xeersoft-inventory")
async def upload_xeersoft_inventory(file: UploadFile = File(...), db=Depends(get_db)):
    """Upload Xeersoft inventory data (Excel with multi-channel stock + 24-month sales history).

    Handles data quirks:
    - Inline text annotations like '330 [special promo -> switch to online model]'
    - Category header rows (no MODEL column)
    - datetime column headers for monthly sales
    """
    try:
        import pandas as pd
        from xeersoft_ingestion import process_xeersoft_dataframe

        contents = await file.read()
        logger.info(f"Xeersoft upload: {file.filename} ({len(contents)} bytes), content_type={file.content_type}")

        # Try Excel first, then CSV — Xeersoft files are often .xlsx disguised as .csv
        df = None
        parse_errors = []
        for parser_name, parser_fn in [
            ('openpyxl', lambda: pd.read_excel(io.BytesIO(contents), engine='openpyxl')),
            ('xlrd', lambda: pd.read_excel(io.BytesIO(contents), engine='xlrd')),
            ('csv', lambda: pd.read_csv(io.BytesIO(contents))),
        ]:
            try:
                df = parser_fn()
                logger.info(f"Parsed with {parser_name}: {len(df)} rows, {len(df.columns)} columns")
                break
            except Exception as e:
                parse_errors.append(f"{parser_name}: {e}")
        if df is None:
            raise ValueError(f"Could not parse file. Tried: {'; '.join(parse_errors)}")

        logger.info(f"Parsed {len(df)} rows, {len(df.columns)} columns")

        # Process through cleaning pipeline
        result = process_xeersoft_dataframe(df)

        # Inject into database
        upsert_result = db.ingest_xeersoft_data(result)

        return {
            "success": True,
            "filename": file.filename,
            "items_processed": len(result['items']),
            "items_skipped": len(result['skipped']),
            "items_upserted": upsert_result.get('items_upserted', 0),
            "sales_months_ingested": upsert_result.get('sales_records', 0),
            "annotations_extracted": len(result['annotations']),
            "skipped_reasons": result['skipped'],
            "annotations": result['annotations'][:20],  # First 20
            "preview": result['items'],
        }
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f"Missing dependency: {e}")
    except Exception as e:
        logger.error(f"Xeersoft upload error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/supplier-master")
async def upload_supplier_master(file: UploadFile = File(...), db=Depends(get_db)):
    """Upload Supplier & Item Master (Excel/CSV with supplier details, item specs, pricing, packaging).

    Flexible column mapping supports common header variations:
    - Supplier ID / Supplier Code
    - Supplier Name / Company Name / Name
    - Contact Person / Contact Name / PIC
    - Email / Email Address
    - Phone / Phone Number / Tel
    - Lead Time / Standard Lead Time / Lead Time Days
    - Currency / Curr
    - Payment Terms / Terms / Payment
    - Address / Supplier Address
    """
    try:
        import pandas as pd
        import numpy as np

        contents = await file.read()
        logger.info(f"Supplier & Item Master upload: {file.filename} ({len(contents)} bytes)")

        # Parse file — try openpyxl (fastest for large files), then xlrd, then csv
        df = None
        parse_errors = []
        for parser_name, parser_fn in [
            ('openpyxl', lambda: pd.read_excel(io.BytesIO(contents), engine='openpyxl', dtype=str)),
            ('xlrd', lambda: pd.read_excel(io.BytesIO(contents), engine='xlrd', dtype=str)),
            ('csv', lambda: pd.read_csv(io.BytesIO(contents), dtype=str)),
        ]:
            try:
                df = parser_fn()
                logger.info(f"Parsed with {parser_name}: {len(df)} rows, {len(df.columns)} cols")
                break
            except Exception as e:
                parse_errors.append(f"{parser_name}: {e}")
        if df is None:
            raise ValueError(f"Could not parse file. Tried: {'; '.join(parse_errors)}")
        # Replace pandas NA/NaN tokens that come back as the string 'nan' when dtype=str
        df = df.where(pd.notna(df), None)

        # Normalize column names: strip, lowercase, underscores
        df.columns = [str(col).strip().lower().replace(' ', '_') for col in df.columns]
        logger.info(f"Columns detected: {list(df.columns)}")

        # Flexible column mapping
        def find_col(candidates, default=None):
            for c in candidates:
                if c in df.columns:
                    return c
            return default

        col_supplier_id = find_col(['supplier_id', 'id', 'supplier_code'])
        col_supplier_code = find_col(['supplier_code', 'supplier_prefix', 'code', 'prefix'])
        col_name = find_col(['supplier_name', 'vendor_name', 'company_name', 'name', 'supplier'])
        col_contact = find_col(['contact_person', 'contact_name', 'pic', 'contact'])
        col_email = find_col(['email', 'email_address', 'e-mail', 'e_mail'])
        col_phone = find_col(['phone', 'phone_number', 'tel', 'telephone', 'mobile'])
        col_lead_time = find_col(['lead_time', 'standard_lead_time', 'lead_time_days', 'leadtime', 'standard_lead_time_days'])
        col_currency = find_col(['currency', 'curr', 'ccy'])
        col_terms = find_col(['payment_terms', 'terms', 'payment', 'pay_terms'])
        col_address = find_col(['address', 'supplier_address'])
        col_moq = find_col(['moq', 'min_order_qty', 'minimum_order_qty', 'minimum_order_quantity'])
        col_category = find_col(['primary_category', 'category', 'product_category'])
        col_status = find_col(['status', 'supplier_status'])
        col_failure_rate = find_col(['failure_rate', 'failure_rate_%', 'defect_rate'])
        col_unit_price = find_col(['unit_price', 'price', 'cost', 'unit_cost'])
        col_model = find_col(['model', 'product_name', 'description', 'item_name'])
        # Item-level columns (optional in supplier master)
        col_item_code = find_col(['item_code', 'sku', 'product_code'])
        col_units_ctn = find_col(['units/ctn', 'units_per_ctn', 'units_per_carton', 'pcs/ctn', 'qty/ctn'])
        col_cbm = find_col(['cbm', 'cbm/ctn', 'cbm_per_ctn', 'volume_cbm'])
        col_weight = find_col(['weight_(kg)', 'weight_per_ctn', 'weight/ctn', 'weight_(kg)/ctn', 'weight', 'weight_kg'])

        if not col_name:
            raise ValueError(f"Could not find a supplier name column. Columns found: {list(df.columns)}")

        # Clean and transform
        suppliers = []
        skipped = []
        for idx, row in df.iterrows():
            name_val = row.get(col_name) if col_name else None
            if pd.isna(name_val) or str(name_val).strip() == '':
                skipped.append(f"Row {idx}: empty supplier name")
                continue

            name_clean = str(name_val).strip()

            # Parse supplier_id
            sid = ''
            if col_supplier_id:
                sid_raw = row.get(col_supplier_id)
                sid = '' if pd.isna(sid_raw) else str(sid_raw).strip()

            # Parse lead time as int
            lead_time = 14
            if col_lead_time:
                lt_raw = row.get(col_lead_time)
                if not pd.isna(lt_raw):
                    try:
                        lead_time = int(float(str(lt_raw).strip()))
                    except (ValueError, TypeError):
                        pass

            def safe_str(col_key):
                if col_key is None:
                    return ''
                v = row.get(col_key)
                return '' if pd.isna(v) else str(v).strip()

            # Resolve supplier_code: prefer dedicated column, fall back to supplier_id
            s_code = safe_str(col_supplier_code).upper() if col_supplier_code else sid.upper()

            supplier = {
                'supplier_id': sid,
                'supplier_code': s_code,
                'name': name_clean,
                'contact_person': safe_str(col_contact),
                'email': safe_str(col_email),
                'phone': safe_str(col_phone),
                'standard_lead_time_days': lead_time,
                'currency': safe_str(col_currency) or 'MYR',
                'payment_terms': safe_str(col_terms),
                'address': safe_str(col_address),
                'moq': 0,
                'category': '',
                'status': 'Active',
            }

            # Parse MOQ
            if col_moq:
                moq_raw = row.get(col_moq)
                if not pd.isna(moq_raw):
                    try:
                        supplier['moq'] = int(float(str(moq_raw).strip()))
                    except (ValueError, TypeError):
                        pass

            # Parse category & status
            if col_category:
                supplier['category'] = safe_str(col_category)
            if col_status:
                supplier['status'] = safe_str(col_status) or 'Active'

            suppliers.append(supplier)

        # Deduplicate suppliers by supplier_code (keep first occurrence per code)
        seen_codes = {}
        unique_suppliers = []
        for s in suppliers:
            key = s.get('supplier_code') or s.get('name', '')
            if key and key not in seen_codes:
                seen_codes[key] = True
                unique_suppliers.append(s)

        logger.info(f"Cleaned {len(suppliers)} rows -> {len(unique_suppliers)} unique suppliers, skipped {len(skipped)}")

        # Upsert into database
        upsert_result = db.upsert_suppliers(unique_suppliers)

        # Upsert all rows into vendor_master table (full record per item)
        vendor_master_rows = []
        vm_skipped = 0
        if col_item_code:
            from xeersoft_ingestion import extract_supplier_code as _extract_sc

            def _safe_str(col_key):
                if col_key is None:
                    return ''
                v2 = row.get(col_key)
                return '' if pd.isna(v2) else str(v2).strip()

            def _safe_float(val, default=0):
                if val is None or (hasattr(pd, 'isna') and pd.isna(val)):
                    return default
                try:
                    return float(str(val).strip())
                except (ValueError, TypeError):
                    return default

            def _safe_int(val, default=0):
                if val is None or (hasattr(pd, 'isna') and pd.isna(val)):
                    return default
                try:
                    return int(float(str(val).strip()))
                except (ValueError, TypeError):
                    return default

            for idx, row in df.iterrows():
                ic = row.get(col_item_code)
                if pd.isna(ic) or str(ic).strip() == '':
                    vm_skipped += 1
                    continue
                sku = str(ic).strip()

                def vm_str(col_key):
                    if col_key is None:
                        return ''
                    v = row.get(col_key)
                    return '' if pd.isna(v) else str(v).strip()

                vendor_master_rows.append({
                    'item_code': sku,
                    'model': vm_str(col_model),
                    'supplier_id_code': _extract_sc(sku),
                    'vendor_name': vm_str(col_name),
                    'contact_person': vm_str(col_contact),
                    'email': vm_str(col_email),
                    'phone': vm_str(col_phone),
                    'primary_category': vm_str(col_category),
                    'lead_time': _safe_int(row.get(col_lead_time) if col_lead_time else None, 14),
                    'currency': vm_str(col_currency) or 'MYR',
                    'payment_terms': vm_str(col_terms),
                    'moq': _safe_int(row.get(col_moq) if col_moq else None, 0),
                    'status': vm_str(col_status) or 'Active',
                    'units_per_ctn': _safe_int(row.get(col_units_ctn) if col_units_ctn else None, 1),
                    'cbm': _safe_float(row.get(col_cbm) if col_cbm else None, 0),
                    'weight_kg': _safe_float(row.get(col_weight) if col_weight else None, 0),
                    'failure_rate': _safe_float(row.get(col_failure_rate) if col_failure_rate else None, 0),
                    'unit_price': _safe_float(row.get(col_unit_price) if col_unit_price else None, 0),
                })

        vm_result = {'upserted': 0}
        if vendor_master_rows:
            vm_result = db.upsert_vendor_master(vendor_master_rows)
            logger.info(f"Vendor master table: {vm_result['upserted']} rows upserted")

        # Rebuild items table from inventory_segments + vendor_master
        items_rebuilt = db.rebuild_items_from_sources()

        return {
            "success": True,
            "filename": file.filename,
            "rows_processed": len(suppliers),
            "suppliers_added": upsert_result.get('added', 0),
            "suppliers_updated": upsert_result.get('updated', 0),
            "items_rebuilt": items_rebuilt,
            "vendor_master_upserted": vm_result.get('upserted', 0),
            "rows_skipped": len(skipped),
            "skipped_reasons": skipped[:20],
            "preview": unique_suppliers,
        }
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f"Missing dependency: {e}")
    except Exception as e:
        logger.error(f"Supplier & Item Master upload error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


