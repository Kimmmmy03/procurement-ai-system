# backend/routers/health.py

import os
from fastapi import APIRouter, Depends
from deps import get_db, get_agent

router = APIRouter(tags=["Health"])


def _db_type(db) -> str:
    if "AzureSQLService" in str(type(db)):
        return "Azure SQL"
    return "SQLite"


@router.get("/")
async def root(db=Depends(get_db)):
    """Root endpoint with system information"""
    db_type = _db_type(db)
    agent_service = get_agent()

    return {
        "message": "Procurement AI System API",
        "version": "1.0.0",
        "status": "operational",
        "database": {
            "type": db_type,
            "status": "connected"
        },
        "features": {
            "ai_agents": {
                "enabled": agent_service is not None,
                "provider": "Microsoft Foundry",
                "agents": [
                    "Guardian-Agent (Quality Gatekeeper)",
                    "Forecaster-Agent (Demand Strategist)",
                    "Logistics-Agent (Shipping Optimizer)",
                    "Procurement-Orchestrator-Main (Workflow Coordinator)"
                ]
            },
            "workflow": "Guardian → Forecaster → Logistics",
            "endpoints": {
                "docs": "/api/docs",
                "health": "/health",
                "ai_workflow": "/api/forecast/run-ai-workflow"
            }
        }
    }


@router.get("/health")
async def health_check(db=Depends(get_db)):
    """Health check endpoint"""
    db_type = _db_type(db)
    db_status = "disconnected"
    db_error = None
    items_count = 0

    try:
        items = db.get_items()
        items_count = len(items)
        db_status = "healthy"
    except Exception as e:
        db_status = "error"
        db_error = str(e)

    agent_service = get_agent()

    return {
        "status": "healthy" if db_status == "healthy" else "degraded",
        "system": "Procurement AI",
        "version": "1.0.0",
        "database": {
            "type": db_type,
            "status": db_status,
            "items_count": items_count,
            "error": db_error
        },
        "ai_agents": {
            "status": "connected" if agent_service else "disconnected",
            "fallback": "using database data" if not agent_service else None
        }
    }
