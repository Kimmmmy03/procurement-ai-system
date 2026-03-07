# backend/main.py

import sys, io
# Force UTF-8 stdout/stderr on Windows to avoid emoji encoding crashes
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from database_factory import get_database_service

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Procurement AI System",
    description="AI-powered procurement with Microsoft Foundry AI Agents",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global services (accessed by deps.py)
agent_service = None
db_service = None


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global agent_service, db_service

    logger.info("🚀 Starting Procurement AI System...")

    # Initialize Database Service
    logger.info("📊 Initializing Database Service...")
    try:
        db_service = get_database_service()
        db_type = "Azure SQL" if "AzureSQLService" in str(type(db_service)) else "SQLite"
        logger.info(f"✅ Database connected successfully: {db_type}")

        items = db_service.get_items()
        logger.info(f"   📦 {len(items)} items loaded from database")
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        raise RuntimeError(f"Database connection failed: {e}")

    # Initialize AI Agents (non-blocking — don't crash if this fails)
    import os
    use_azure_ai = os.getenv('USE_AZURE_AI', 'false').lower() == 'true'
    if not use_azure_ai:
        logger.info("⏭️  Azure AI Agents disabled (USE_AZURE_AI=false). Running locally with database only.")
        agent_service = None
    else:
        logger.info("🤖 Initializing Microsoft Foundry AI Agents...")
        try:
            from azure_agent_service import AzureAgentService
            agent_service = AzureAgentService(db_service=db_service)
            logger.info("✅ Azure AI Agents initialized successfully")
        except ImportError as e:
            logger.warning(f"⚠️  Azure AI SDK not available: {e}")
            agent_service = None
        except Exception as e:
            logger.warning(f"⚠️  Azure AI Agents initialization failed: {e}")
            logger.warning("   System will continue with database data only")
            agent_service = None

    logger.info("✅ Procurement AI System ready!")
    logger.info("=" * 60)


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("🛑 Shutting down Procurement AI System...")


# Register all routers
from routers import (
    health, dashboard, agents, forecast, upload,
    purchase_requests, approval, orders, analytics,
    role_mapping, database_admin, suppliers
)
from routers import custom_seasonality
from routers.warehouse import router as warehouse_router

app.include_router(health.router)
app.include_router(dashboard.router)
app.include_router(agents.router)
app.include_router(forecast.router)
app.include_router(upload.router)
app.include_router(purchase_requests.router)
app.include_router(approval.router)
app.include_router(orders.router)
app.include_router(analytics.router)
app.include_router(role_mapping.router)
app.include_router(database_admin.router)
app.include_router(suppliers.router)
app.include_router(custom_seasonality.router)
app.include_router(warehouse_router)


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Global exception: {exc}")
    return {"error": "Internal server error", "detail": str(exc), "status_code": 500}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")
