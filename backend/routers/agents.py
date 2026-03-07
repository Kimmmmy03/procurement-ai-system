# backend/routers/agents.py

from fastapi import APIRouter, Depends
from deps import get_db, get_agent

router = APIRouter(prefix="/api/agents", tags=["AI Agents"])


@router.get("/status")
async def agents_status(db=Depends(get_db)):
    """Check status of all AI agents"""
    agent_service = get_agent()
    if not agent_service:
        return {
            "status": "unavailable",
            "message": "AI agents not configured. Using database data.",
            "agents": db.get_agent_status()
        }

    try:
        return {
            "status": "available",
            "agents": {
                "guardian": {"name": "Guardian-Agent", "role": "Quality Gatekeeper", "status": "ready"},
                "forecaster": {"name": "Forecaster-Agent", "role": "Demand Strategist", "status": "ready"},
                "logistics": {"name": "Logistics-Agent", "role": "Shipping Optimizer", "status": "ready"}
            },
            "workflow": "Start → Guardian → Forecaster → Logistics → End"
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


@router.get("/test")
async def test_agents(db=Depends(get_db)):
    """Test AI agents with sample data"""
    agent_service = get_agent()
    if not agent_service:
        return db.get_test_agent_response()

    try:
        test_request = "Tell me what you can help with."
        results = {"test_request": test_request, "agents_tested": []}

        for agent_key in ["guardian", "forecaster", "logistics"]:
            try:
                result = agent_service._call_agent(
                    agent_service.AGENTS[agent_key], test_request
                )
                results["agents_tested"].append({
                    "agent": agent_key.capitalize(),
                    "status": result.get("status"),
                    "response": result.get("output", "")[:200] + "..."
                })
            except Exception as e:
                results["agents_tested"].append({
                    "agent": agent_key.capitalize(),
                    "status": "error",
                    "error": str(e)
                })

        return results
    except Exception as e:
        return {"status": "error", "error": str(e)}
