# routers/warehouse.py
from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any
from deps import get_db

router = APIRouter(prefix="/api/warehouse", tags=["warehouse"])


@router.get("/stock")
async def get_warehouse_stock(search: str = "", db=Depends(get_db)):
    """Get all inventory segments with stock by warehouse/channel."""
    try:
        with db.get_connection() as conn:
            cursor = conn.cursor()

            query = """
                SELECT sku, product, category,
                       sellable_main_warehouse, sellable_tiktok, sellable_shopee, sellable_lazada,
                       sellable_estore, reserved_b2b_projects, sellable_corporate, sellable_east_mas,
                       sellable_minor_bp, quarantine_rework, stock_bp, stock_dm,
                       quarantine_sirim, quarantine_incomplete, stock_mgit
                FROM inventory_segments
            """

            if search:
                query += " WHERE sku LIKE ? OR product LIKE ?"
                cursor.execute(query, (f'%{search}%', f'%{search}%'))
            else:
                cursor.execute(query)

            columns = [desc[0] for desc in cursor.description]
            rows = cursor.fetchall()

            items = []
            for row in rows:
                item = dict(zip(columns, row))

                # Calculate totals
                # Total Stocks In Hand (Exclude NM1, 2, 3, 8, 9, 10, BP, DM, INC2)
                exclude_fields = ['reserved_b2b_projects', 'sellable_corporate', 'sellable_east_mas',
                                  'sellable_lazada', 'sellable_shopee', 'sellable_estore',
                                  'stock_bp', 'stock_dm', 'quarantine_incomplete']

                all_stock_fields = ['sellable_main_warehouse', 'sellable_tiktok', 'sellable_shopee',
                                    'sellable_lazada', 'sellable_estore', 'reserved_b2b_projects',
                                    'sellable_corporate', 'sellable_east_mas', 'sellable_minor_bp',
                                    'quarantine_rework', 'stock_bp', 'stock_dm',
                                    'quarantine_sirim', 'quarantine_incomplete', 'stock_mgit']

                total_in_hand = sum(item.get(f, 0) or 0 for f in all_stock_fields if f not in exclude_fields)
                total_stocks = sum(item.get(f, 0) or 0 for f in all_stock_fields)

                item['total_stocks_in_hand'] = total_in_hand
                item['total_stocks_incoming'] = 0  # Placeholder - no incoming data in current schema
                item['total_stocks'] = total_stocks

                items.append(item)

            # Summary totals
            summary = {}
            sum_fields = ['sellable_main_warehouse', 'sellable_tiktok', 'sellable_shopee',
                          'sellable_lazada', 'sellable_estore', 'reserved_b2b_projects',
                          'sellable_corporate', 'sellable_east_mas', 'sellable_minor_bp',
                          'quarantine_rework', 'stock_bp', 'stock_dm',
                          'quarantine_sirim', 'quarantine_incomplete', 'stock_mgit']
            for f in sum_fields:
                summary[f] = sum(item.get(f, 0) or 0 for item in items)

            summary['total_stocks_in_hand'] = sum(item.get('total_stocks_in_hand', 0) for item in items)
            summary['total_stocks_incoming'] = sum(item.get('total_stocks_incoming', 0) for item in items)
            summary['total_stocks'] = sum(item.get('total_stocks', 0) for item in items)
            summary['total_skus'] = len(items)

            return {
                "success": True,
                "items": items,
                "summary": summary
            }
    except Exception as e:
        return {"success": False, "error": str(e), "items": [], "summary": {}}


@router.put("/stock/{sku}")
async def update_warehouse_stock(sku: str, data: Dict[str, Any], db=Depends(get_db)):
    """Update stock values for a specific SKU."""
    try:
        result = db.update_inventory_segment(sku, data)
        if result:
            return {"success": True, "message": f"Stock updated for {sku}"}
        return {"success": False, "error": "No valid fields to update or SKU not found"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
