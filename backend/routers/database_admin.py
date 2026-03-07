# backend/routers/database_admin.py

from fastapi import APIRouter, Depends, HTTPException
from deps import get_db

router = APIRouter(prefix="/api/database", tags=["Database"])


@router.get("/items")
async def get_all_items(db=Depends(get_db)):
    """Get all items from database"""
    try:
        items = db.get_items()
        return {"success": True, "count": len(items), "items": items}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/purchase-orders")
async def clear_purchase_orders(db=Depends(get_db)):
    """Delete all purchase orders and related line items/revisions"""
    try:
        with db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM po_revision_history")
            cursor.execute("DELETE FROM po_line_items")
            cursor.execute("DELETE FROM purchase_orders")
        return {"success": True, "message": "All purchase orders cleared"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_database_stats(db=Depends(get_db)):
    """Get database statistics"""
    db_type = "Azure SQL" if "AzureSQLService" in str(type(db)) else "SQLite"

    try:
        items = db.get_items()
        batches = db.get_batch_list()
        orders = db.get_purchase_orders()

        return {
            "success": True,
            "statistics": {
                "database_type": db_type,
                "total_items": len(items),
                "total_batches": len(batches.get("batches", [])),
                "total_orders": len(orders.get("orders", [])),
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
