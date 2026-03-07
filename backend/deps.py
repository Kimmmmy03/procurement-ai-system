# backend/deps.py
"""Shared FastAPI dependencies for all routers"""

from fastapi import HTTPException


def get_db():
    """Get database service — raises 503 if not initialized"""
    from main import db_service
    if not db_service:
        raise HTTPException(status_code=503, detail="Database service not available")
    return db_service


def get_agent():
    """Get AI agent service — returns None if not available"""
    from main import agent_service
    return agent_service
