# backend/database_factory.py

import os
from dotenv import load_dotenv

load_dotenv()

def get_database_service():
    """Database factory - switches between Azure SQL and SQLite"""
    use_azure = os.getenv('USE_AZURE_SQL', 'false').lower() == 'true'
    
    if use_azure:
        try:
            from azure_sql_service import AzureSQLService
            print("[OK] Using Azure SQL Database")
            return AzureSQLService()
        except Exception as e:
            print(f"[ERROR] Azure SQL failed: {e}")
            print("[WARN] Falling back to SQLite...")
            from database_service import DatabaseService
            return DatabaseService()
    else:
        from database_service import DatabaseService
        print("[OK] Using SQLite Database (Development Mode)")
        return DatabaseService()