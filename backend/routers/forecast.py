# backend/routers/forecast.py

from fastapi import APIRouter, Depends
from typing import Dict, Any
import logging
from deps import get_db, get_agent

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/forecast", tags=["Forecast"])


@router.post("/run-ai-workflow")
async def run_ai_workflow(batch_data: Dict[str, Any], db=Depends(get_db)):
    """Run complete AI workflow (Guardian → Forecaster → Logistics)

    Always uses the full 5-step pipeline via db service:
    1. Get items from database
    2. Validate data quality
    3. Send to AI agents (or fallback)
    4. Parse AI results into purchase requests
    5. Save batch + forecast items to database
    """
    logger.info(f"Starting AI workflow for batch: {batch_data.get('batch_id')}")
    return db.get_ai_workflow_result(batch_data)


@router.post("/run")
async def run_forecast(config: Dict[str, Any], db=Depends(get_db)):
    """Legacy forecast endpoint"""
    return db.get_forecast_result(config)


@router.post("/run-guardian")
async def run_guardian(batch_data: Dict[str, Any], db=Depends(get_db)):
    """Run Guardian Agent only"""
    agent_service = get_agent()
    if not agent_service:
        return db.get_guardian_result(batch_data)
    try:
        result = agent_service.run_guardian_agent(batch_data)
        return {"success": True, "result": result}
    except Exception:
        return db.get_guardian_result(batch_data)


@router.post("/run-forecaster")
async def run_forecaster(guardian_report: Dict[str, Any], db=Depends(get_db)):
    """Run Forecaster Agent only"""
    agent_service = get_agent()
    if not agent_service:
        return db.get_forecaster_result(guardian_report)
    try:
        result = agent_service.run_forecaster_agent(guardian_report)
        return {"success": True, "result": result}
    except Exception:
        return db.get_forecaster_result(guardian_report)


@router.post("/run-logistics")
async def run_logistics(forecaster_output: Dict[str, Any], db=Depends(get_db)):
    """Run Logistics Agent only"""
    agent_service = get_agent()
    if not agent_service:
        return db.get_logistics_result(forecaster_output)
    try:
        result = agent_service.run_logistics_agent(forecaster_output)
        return {"success": True, "result": result}
    except Exception:
        return db.get_logistics_result(forecaster_output)


@router.post("/seasonality-analysis")
async def seasonality_analysis(body: Dict[str, Any], db=Depends(get_db)):
    """Detect seasonal patterns from monthly sales history."""
    plan_start = body.get("plan_start", "")
    plan_end = body.get("plan_end", "")
    try:
        result = db.get_seasonality_analysis(plan_start, plan_end)
        return {"success": True, **result}
    except Exception as e:
        logger.error(f"Seasonality analysis error: {e}")
        return {"success": False, "error": str(e), "detected_events": [], "sku_multipliers": {}, "summary_text": "Analysis failed."}


@router.get("/ml-baseline")
async def get_ml_baseline(db=Depends(get_db)):
    """Get ML baseline 3-month forecast for all SKUs with sales history."""
    try:
        from ml_forecasting_service import MLForecastingService
        ml = MLForecastingService(db)
        result = ml.forecast_all_skus()
        return {"success": True, **result}
    except Exception as e:
        logger.error(f"ML baseline error: {e}")
        return {"success": False, "error": str(e)}


@router.get("/ml-baseline/{sku}")
async def get_ml_baseline_sku(sku: str, db=Depends(get_db)):
    """Get ML baseline 3-month forecast for a specific SKU."""
    try:
        from ml_forecasting_service import MLForecastingService
        ml = MLForecastingService(db)
        result = ml.forecast_sku(sku)
        return {"success": True, **result}
    except Exception as e:
        logger.error(f"ML baseline error for {sku}: {e}")
        return {"success": False, "error": str(e)}
