# backend/azure_sql_service.py

"""
Azure SQL Database Service for Procurement System

This service handles all database operations and orchestrates the AI workflow:

WORKFLOW STEPS:
1. Get data from database (populated via Xeersoft uploads)
2. Verify data quality  
3. Send to AI agents (via Azure AI Foundry)
4. Parse AI results
5. Save to database
"""

import pyodbc
import json
import math
import os
import re
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from contextlib import contextmanager
from dotenv import load_dotenv
import logging

load_dotenv()

logger = logging.getLogger(__name__)


class AzureSQLService:
    """
    Azure SQL Database service for procurement system
    
    Orchestrates the complete workflow:
    Database → Verify → AI Agents → Parse → Save
    """
    
    def __init__(self):
        """Initialize SQL Service with AI Agent integration"""
        
        self.connection_string = self._build_connection_string()
        
        # Initialize database tables
        self.init_database()
        
        # Initialize AI Agent Service (REQUIRED)
        try:
            from azure_agent_service import AzureAgentService
            self.agent_service = AzureAgentService()
            logger.info("✅ Azure Agent Service initialized successfully")
        except Exception as e:
            logger.error(f"❌ CRITICAL: Could not initialize Agent Service: {e}")
            raise Exception("AI Agent Service is required. Please check azure_agent_service.py configuration.")
    
    def _build_connection_string(self) -> str:
        """Build Azure SQL connection string from environment variables"""
        server = os.getenv('AZURE_SQL_SERVER')
        database = os.getenv('AZURE_SQL_DATABASE')
        username = os.getenv('AZURE_SQL_USERNAME')
        password = os.getenv('AZURE_SQL_PASSWORD')
        driver = os.getenv('AZURE_SQL_DRIVER', 'ODBC Driver 18 for SQL Server')
        
        if not all([server, database, username, password]):
            raise ValueError("Missing required Azure SQL environment variables")
        
        return (
            f"Driver={{{driver}}};"
            f"Server=tcp:{server},1433;"
            f"Database={database};"
            f"Uid={username};"
            f"Pwd={password};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=yes;"
            f"Connection Timeout=30;"
        )
    
    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        conn = pyodbc.connect(self.connection_string)
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()
    
    def init_database(self):
        """Initialize database with all required tables"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # Items master table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'items')
                CREATE TABLE items (
                    sku NVARCHAR(50) PRIMARY KEY,
                    product NVARCHAR(255) NOT NULL,
                    category NVARCHAR(100) DEFAULT 'General',
                    current_stock INT DEFAULT 0,
                    sales_last_30_days INT DEFAULT 0,
                    sales_last_60_days INT DEFAULT 0,
                    sales_last_90_days INT DEFAULT 0,
                    unit_price DECIMAL(10,2) DEFAULT 0.0,
                    supplier NVARCHAR(255),
                    lead_time_days INT DEFAULT 14,
                    moq INT DEFAULT 50,
                    failure_rate DECIMAL(5,2) DEFAULT 0.0,
                    last_updated DATETIME DEFAULT GETDATE()
                )
            ''')
            
            # Forecast batches
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'forecast_batches')
                CREATE TABLE forecast_batches (
                    batch_id NVARCHAR(50) PRIMARY KEY,
                    created_date DATETIME DEFAULT GETDATE(),
                    created_by NVARCHAR(100) DEFAULT 'System',
                    config_json NVARCHAR(MAX),
                    total_items INT,
                    total_value DECIMAL(15,2),
                    critical_items INT,
                    warning_items INT,
                    status NVARCHAR(50) DEFAULT 'PENDING_APPROVAL',
                    approved_by NVARCHAR(100),
                    approved_date DATETIME,
                    ai_workflow_result NVARCHAR(MAX)
                )
            ''')
            
            # Forecast items (Purchase Requests)
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'forecast_items')
                CREATE TABLE forecast_items (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    batch_id NVARCHAR(50),
                    sku NVARCHAR(50),
                    forecasted_qty INT,
                    optimized_qty INT,
                    unit_price DECIMAL(10,2),
                    line_value DECIMAL(15,2),
                    risk_level NVARCHAR(20),
                    ai_insight NVARCHAR(1000),
                    guardian_status NVARCHAR(50),
                    guardian_reason NVARCHAR(500),
                    forecaster_recommendation NVARCHAR(500),
                    logistics_optimization NVARCHAR(500),
                    festival_boost_applied BIT DEFAULT 0,
                    container_optimization NVARCHAR(255),
                    FOREIGN KEY (batch_id) REFERENCES forecast_batches(batch_id),
                    FOREIGN KEY (sku) REFERENCES items(sku)
                )
            ''')
            
            # Agent execution log table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'agent_execution_log')
                CREATE TABLE agent_execution_log (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    batch_id NVARCHAR(50),
                    agent_name NVARCHAR(50),
                    execution_time DATETIME DEFAULT GETDATE(),
                    status NVARCHAR(20),
                    input_data NVARCHAR(MAX),
                    output_data NVARCHAR(MAX),
                    error_message NVARCHAR(MAX),
                    FOREIGN KEY (batch_id) REFERENCES forecast_batches(batch_id)
                )
            ''')

            # Purchase requests table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'purchase_requests')
                CREATE TABLE [dbo].[purchase_requests] (
                    RequestID INT IDENTITY(1,1) PRIMARY KEY,
                    SKU NVARCHAR(50) NOT NULL,
                    ProductName NVARCHAR(255) NOT NULL,
                    AiRecommendedQty INT NOT NULL,
                    UserOverriddenQty INT NULL,
                    RiskLevel NVARCHAR(20) NOT NULL,
                    AiInsightText NVARCHAR(1000),
                    TotalValue DECIMAL(15,2) NOT NULL DEFAULT 0,
                    Last30DaysSales INT DEFAULT 0,
                    Last60DaysSales INT DEFAULT 0,
                    CurrentStock INT DEFAULT 0,
                    SupplierLeadTime INT DEFAULT 14,
                    StockCoverageDays INT DEFAULT 0,
                    SupplierName NVARCHAR(255),
                    MinOrderQty INT DEFAULT 1,
                    OverrideReason NVARCHAR(100) NULL,
                    OverrideDetails NVARCHAR(1000) NULL,
                    CreatedDate DATETIME DEFAULT GETDATE(),
                    LastModified DATETIME DEFAULT GETDATE()
                )
            ''')

            # Add new columns to purchase_requests if they don't exist
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'Status')
                ALTER TABLE purchase_requests ADD Status NVARCHAR(50) DEFAULT 'Draft'
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'RejectionReason')
                ALTER TABLE purchase_requests ADD RejectionReason NVARCHAR(1000)
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ApprovalDate')
                ALTER TABLE purchase_requests ADD ApprovalDate DATETIME
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ApproverID')
                ALTER TABLE purchase_requests ADD ApproverID INT
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'TotalCBM')
                ALTER TABLE purchase_requests ADD TotalCBM DECIMAL(10,2) DEFAULT 0.0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ContainerStrategy')
                ALTER TABLE purchase_requests ADD ContainerStrategy NVARCHAR(50) DEFAULT 'Local Bulk'
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ContainerFillRate')
                ALTER TABLE purchase_requests ADD ContainerFillRate INT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'EstimatedTransitDays')
                ALTER TABLE purchase_requests ADD EstimatedTransitDays INT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'AiReasoning')
                ALTER TABLE purchase_requests ADD AiReasoning NVARCHAR(MAX)
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'TotalWeightKg')
                ALTER TABLE purchase_requests ADD TotalWeightKg DECIMAL(10,2) DEFAULT 0.0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'LogisticsVehicle')
                ALTER TABLE purchase_requests ADD LogisticsVehicle NVARCHAR(100) DEFAULT ''
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ContainerSize')
                ALTER TABLE purchase_requests ADD ContainerSize NVARCHAR(50) DEFAULT ''
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'ContainerCount')
                ALTER TABLE purchase_requests ADD ContainerCount INT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'RecommendedLorry')
                ALTER TABLE purchase_requests ADD RecommendedLorry NVARCHAR(50) DEFAULT ''
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'LorryCount')
                ALTER TABLE purchase_requests ADD LorryCount INT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'FillUpSuggestion')
                ALTER TABLE purchase_requests ADD FillUpSuggestion NVARCHAR(500) DEFAULT ''
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'WeightUtilizationPct')
                ALTER TABLE purchase_requests ADD WeightUtilizationPct INT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_requests') AND name = 'SpareCbm')
                ALTER TABLE purchase_requests ADD SpareCbm DECIMAL(10,2) DEFAULT 0.0
            ''')

            # Purchase orders table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'purchase_orders')
                CREATE TABLE [dbo].[purchase_orders] (
                    PO_ID INT IDENTITY(1,1) PRIMARY KEY,
                    RequestID INT,
                    SupplierName NVARCHAR(255),
                    OrderDate DATETIME DEFAULT GETDATE(),
                    TotalAmount DECIMAL(15,2) DEFAULT 0,
                    Status NVARCHAR(50) DEFAULT 'DRAFT',
                    EmailSubject NVARCHAR(500),
                    EmailBody NVARCHAR(MAX),
                    FOREIGN KEY (RequestID) REFERENCES purchase_requests(RequestID)
                )
            ''')

            # Users table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'users')
                CREATE TABLE [dbo].[users] (
                    UserID INT IDENTITY(1,1) PRIMARY KEY,
                    Name NVARCHAR(255) NOT NULL,
                    Role NVARCHAR(100) NOT NULL,
                    ApprovalLimit DECIMAL(15,2) DEFAULT 0,
                    AssignedSuppliers NVARCHAR(MAX)
                )
            ''')

            # Procurement users table (for Role Mapping demo)
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'procurement_users')
                CREATE TABLE [dbo].[procurement_users] (
                    UserID INT IDENTITY(1,1) PRIMARY KEY,
                    UserName NVARCHAR(255) NOT NULL,
                    Role NVARCHAR(100) NOT NULL,
                    ApprovalLimit DECIMAL(15,2) DEFAULT 0,
                    AssignedSuppliers NVARCHAR(MAX),
                    ReportsTo INT NULL
                )
            ''')

            # Safe migration: add ReportsTo column if missing
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('procurement_users') AND name = 'ReportsTo')
                    ALTER TABLE procurement_users ADD ReportsTo INT NULL
            ''')

            # Monthly sales history table for seasonality detection
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'monthly_sales_history')
                CREATE TABLE [dbo].[monthly_sales_history] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    sku NVARCHAR(50) NOT NULL,
                    year INT NOT NULL,
                    month INT NOT NULL,
                    sales_qty INT NOT NULL,
                    CONSTRAINT UQ_monthly_sales UNIQUE (sku, year, month),
                    FOREIGN KEY (sku) REFERENCES items(sku)
                )
            ''')

            # ── Phase 1 schema additions ────────────────────────────────

            # Add lifecycle_status and demand_type to items
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('items') AND name = 'lifecycle_status')
                ALTER TABLE items ADD lifecycle_status NVARCHAR(20) DEFAULT 'ACTIVE'
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('items') AND name = 'demand_type')
                ALTER TABLE items ADD demand_type NVARCHAR(20) DEFAULT 'STANDARD_STOCK'
            ''')
            # Packaging/logistics columns on items
            for col_name, col_def in [
                ('units_per_ctn', 'INT DEFAULT 1'),
                ('cbm_per_ctn', 'DECIMAL(10,4) DEFAULT 0.05'),
                ('weight_per_ctn', 'DECIMAL(10,2) DEFAULT 10.0'),
            ]:
                cursor.execute(f'''
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('items') AND name = '{col_name}')
                    ALTER TABLE items ADD {col_name} {col_def}
                ''')

            # Set lifecycle/demand_type on specific items
            cursor.execute("UPDATE items SET lifecycle_status = 'PHASING_OUT' WHERE sku = 'SKU-M002'")
            cursor.execute("UPDATE items SET lifecycle_status = 'NEW', demand_type = 'NEW_PRODUCT' WHERE sku = 'SKU-E002'")
            cursor.execute("UPDATE items SET demand_type = 'CUSTOMER_INDENT' WHERE sku = 'SKU-S002'")
            # Additional lifecycle assignments for new SKUs
            cursor.execute("UPDATE items SET lifecycle_status = 'NEW', demand_type = 'NEW_PRODUCT' WHERE sku = 'SKU-E009'")
            cursor.execute("UPDATE items SET lifecycle_status = 'NEW', demand_type = 'NEW_PRODUCT' WHERE sku = 'SKU-E006'")
            cursor.execute("UPDATE items SET lifecycle_status = 'PHASING_OUT' WHERE sku = 'SKU-M006'")
            cursor.execute("UPDATE items SET demand_type = 'CUSTOMER_INDENT' WHERE sku = 'SKU-M008'")
            cursor.execute("UPDATE items SET demand_type = 'CUSTOMER_INDENT' WHERE sku = 'SKU-RM01'")
            cursor.execute("UPDATE items SET lifecycle_status = 'DISCONTINUED' WHERE sku = 'SKU-O003'")

            # Inventory segmentation table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'inventory_segments')
                CREATE TABLE [dbo].[inventory_segments] (
                    sku NVARCHAR(50) PRIMARY KEY,
                    product NVARCHAR(255) DEFAULT '',
                    category NVARCHAR(100) DEFAULT 'General',
                    sellable_main_warehouse INT DEFAULT 0,
                    sellable_tiktok INT DEFAULT 0,
                    sellable_shopee INT DEFAULT 0,
                    sellable_lazada INT DEFAULT 0,
                    sellable_estore INT DEFAULT 0,
                    reserved_b2b_projects INT DEFAULT 0,
                    sellable_corporate INT DEFAULT 0,
                    sellable_east_mas INT DEFAULT 0,
                    sellable_minor_bp INT DEFAULT 0,
                    quarantine_sirim INT DEFAULT 0,
                    quarantine_rework INT DEFAULT 0,
                    stock_bp INT DEFAULT 0,
                    stock_dm INT DEFAULT 0,
                    quarantine_incomplete INT DEFAULT 0,
                    stock_mgit INT DEFAULT 0,
                    sales_last_30_days INT DEFAULT 0,
                    sales_last_60_days INT DEFAULT 0,
                    sales_last_90_days INT DEFAULT 0
                )
            ''')

            # Migration: add product, category, sales columns to inventory_segments
            for col_sql in [
                "ALTER TABLE inventory_segments ADD product NVARCHAR(255) DEFAULT ''",
                "ALTER TABLE inventory_segments ADD category NVARCHAR(100) DEFAULT 'General'",
                "ALTER TABLE inventory_segments ADD sales_last_30_days INT DEFAULT 0",
                "ALTER TABLE inventory_segments ADD sales_last_60_days INT DEFAULT 0",
                "ALTER TABLE inventory_segments ADD sales_last_90_days INT DEFAULT 0",
            ]:
                try:
                    cursor.execute(f"IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('inventory_segments') AND name = '{col_sql.split('ADD ')[1].split(' ')[0]}') {col_sql}")
                except Exception:
                    pass

            # Migration: add new warehouse stock columns
            for col_name in ['sellable_estore', 'sellable_corporate', 'sellable_east_mas',
                             'sellable_minor_bp', 'stock_bp', 'stock_dm',
                             'quarantine_incomplete', 'stock_mgit']:
                try:
                    cursor.execute(f"IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('inventory_segments') AND name = '{col_name}') ALTER TABLE inventory_segments ADD {col_name} INT DEFAULT 0")
                except Exception:
                    pass

            # Migration: drop FK constraint from inventory_segments -> items
            cursor.execute('''
                DECLARE @fk NVARCHAR(255)
                SELECT @fk = fk.name
                FROM sys.foreign_keys fk
                JOIN sys.tables t ON fk.parent_object_id = t.object_id
                WHERE t.name = 'inventory_segments'
                  AND fk.referenced_object_id = OBJECT_ID('items')
                IF @fk IS NOT NULL
                    EXEC('ALTER TABLE inventory_segments DROP CONSTRAINT ' + @fk)
            ''')

            # Migration: rename vendors -> suppliers
            cursor.execute('''
                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'vendors')
                AND NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'suppliers')
                EXEC sp_rename 'vendors', 'suppliers'
            ''')
            # Migration: rename vendor_code -> supplier_code in suppliers
            cursor.execute('''
                IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('suppliers') AND name = 'vendor_code')
                EXEC sp_rename 'suppliers.vendor_code', 'supplier_code', 'COLUMN'
            ''')
            # Migration: rename vendor_id -> supplier_id in items
            cursor.execute('''
                IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('items') AND name = 'vendor_id')
                EXEC sp_rename 'items.vendor_id', 'supplier_id', 'COLUMN'
            ''')
            # Migration: rename vendor_id -> supplier_id in inventory_segments
            cursor.execute('''
                IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('inventory_segments') AND name = 'vendor_id')
                EXEC sp_rename 'inventory_segments.vendor_id', 'supplier_id', 'COLUMN'
            ''')
            # Migration: rename constraint (only if old exists AND new doesn't)
            cursor.execute('''
                IF EXISTS (SELECT * FROM sys.objects WHERE name = 'UQ_vendor_name' AND type = 'UQ')
                AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'UQ_supplier_name' AND type = 'UQ')
                EXEC sp_rename 'UQ_vendor_name', 'UQ_supplier_name', 'OBJECT'
            ''')
            # Drop leftover vendors table if suppliers already exists
            cursor.execute('''
                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'vendors')
                AND EXISTS (SELECT * FROM sys.tables WHERE name = 'suppliers')
                DROP TABLE vendors
            ''')

            # Suppliers table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'suppliers')
                CREATE TABLE [dbo].[suppliers] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    supplier_id NVARCHAR(50) DEFAULT '',
                    supplier_code NVARCHAR(20) DEFAULT '',
                    name NVARCHAR(255) NOT NULL,
                    contact_person NVARCHAR(255) DEFAULT '',
                    email NVARCHAR(255) DEFAULT '',
                    phone NVARCHAR(100) DEFAULT '',
                    standard_lead_time_days INT DEFAULT 14,
                    currency NVARCHAR(10) DEFAULT 'MYR',
                    payment_terms NVARCHAR(255) DEFAULT '',
                    address NVARCHAR(500) DEFAULT '',
                    created_date DATETIME DEFAULT GETDATE(),
                    last_updated DATETIME DEFAULT GETDATE(),
                    CONSTRAINT UQ_supplier_name UNIQUE(name)
                )
            ''')

            # Add supplier_code column to suppliers if missing (migration)
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('suppliers') AND name = 'supplier_code')
                ALTER TABLE suppliers ADD supplier_code NVARCHAR(20) DEFAULT ''
            ''')

            # Add supplier_id FK columns to items and inventory_segments
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('items') AND name = 'supplier_id')
                ALTER TABLE items ADD supplier_id INT REFERENCES suppliers(id)
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('inventory_segments') AND name = 'supplier_id')
                ALTER TABLE inventory_segments ADD supplier_id INT REFERENCES suppliers(id)
            ''')

            # Add PO lifecycle columns
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_orders') AND name = 'etd_date')
                ALTER TABLE purchase_orders ADD etd_date DATETIME
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_orders') AND name = 'supplier_confirmed')
                ALTER TABLE purchase_orders ADD supplier_confirmed BIT DEFAULT 0
            ''')
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_orders') AND name = 'received_date')
                ALTER TABLE purchase_orders ADD received_date DATETIME
            ''')

            # Grouped PO columns
            for col_name, col_def in [
                ('RequestIDs', "NVARCHAR(MAX) DEFAULT ''"),
                ('original_total_value', 'DECIMAL(15,2) DEFAULT 0'),
                ('confirmed_total_value', 'DECIMAL(15,2) DEFAULT 0'),
            ]:
                cursor.execute(f'''
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_orders') AND name = '{col_name}')
                    ALTER TABLE purchase_orders ADD {col_name} {col_def}
                ''')

            # PO line items table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'po_line_items')
                CREATE TABLE [dbo].[po_line_items] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    po_id INT NOT NULL,
                    request_id INT,
                    sku NVARCHAR(50),
                    product_name NVARCHAR(255),
                    requested_qty INT DEFAULT 0,
                    requested_price DECIMAL(12,2) DEFAULT 0,
                    confirmed_qty INT DEFAULT 0,
                    confirmed_price DECIMAL(12,2) DEFAULT 0,
                    FOREIGN KEY (po_id) REFERENCES purchase_orders(PO_ID)
                )
            ''')

            # PO logistics columns
            for col_name, col_def in [
                ('total_cbm', 'DECIMAL(10,2) DEFAULT 0.0'),
                ('total_weight_kg', 'DECIMAL(10,2) DEFAULT 0.0'),
                ('logistics_vehicle', "NVARCHAR(100) DEFAULT ''"),
                ('logistics_strategy', "NVARCHAR(50) DEFAULT 'Local Bulk'"),
                ('utilization_percentage', 'DECIMAL(5,1) DEFAULT 0.0'),
            ]:
                cursor.execute(f'''
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('purchase_orders') AND name = '{col_name}')
                    ALTER TABLE purchase_orders ADD {col_name} {col_def}
                ''')

            # Shipping documents table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'shipping_documents')
                CREATE TABLE [dbo].[shipping_documents] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    po_id INT NOT NULL,
                    doc_type NVARCHAR(50) NOT NULL,
                    file_url NVARCHAR(500) NOT NULL,
                    uploaded_at DATETIME DEFAULT GETDATE(),
                    FOREIGN KEY (po_id) REFERENCES purchase_orders(PO_ID)
                )
            ''')

            # Vendor master table — stores all columns from vendor_master.xlsx per item
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'vendor_master')
                CREATE TABLE [dbo].[vendor_master] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    item_code NVARCHAR(50) NOT NULL,
                    model NVARCHAR(255) DEFAULT '',
                    supplier_id_code NVARCHAR(20) DEFAULT '',
                    vendor_name NVARCHAR(255) DEFAULT '',
                    contact_person NVARCHAR(255) DEFAULT '',
                    email NVARCHAR(255) DEFAULT '',
                    phone NVARCHAR(100) DEFAULT '',
                    primary_category NVARCHAR(255) DEFAULT '',
                    lead_time INT DEFAULT 14,
                    currency NVARCHAR(10) DEFAULT 'MYR',
                    payment_terms NVARCHAR(255) DEFAULT '',
                    moq INT DEFAULT 0,
                    status NVARCHAR(50) DEFAULT 'Active',
                    units_per_ctn INT DEFAULT 1,
                    cbm DECIMAL(10,4) DEFAULT 0,
                    weight_kg DECIMAL(10,2) DEFAULT 0,
                    failure_rate DECIMAL(8,4) DEFAULT 0,
                    unit_price DECIMAL(12,2) DEFAULT 0,
                    created_date DATETIME DEFAULT GETDATE(),
                    last_updated DATETIME DEFAULT GETDATE(),
                    CONSTRAINT UQ_vendor_master_item_code UNIQUE(item_code)
                )
            ''')

            # Approval status table — dedicated table for the approval workflow
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'approval_status')
                CREATE TABLE [dbo].[approval_status] (
                    ApprovalID     INT IDENTITY(1,1) PRIMARY KEY,
                    RequestID      INT NOT NULL,
                    Status         NVARCHAR(50) NOT NULL DEFAULT 'Pending',
                    SubmittedDate  DATETIME DEFAULT GETDATE(),
                    SubmittedByID  INT NULL,
                    ApproverID     INT NULL,
                    ActionDate     DATETIME NULL,
                    RejectionReason NVARCHAR(MAX) NULL,
                    Notes          NVARCHAR(MAX) NULL,
                    LastModified   DATETIME DEFAULT GETDATE(),
                    FOREIGN KEY (RequestID) REFERENCES purchase_requests(RequestID)
                )
            ''')
            # Safe migration: add SubmittedByID if missing (for existing deployments)
            cursor.execute('''
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('approval_status') AND name = 'SubmittedByID')
                ALTER TABLE approval_status ADD SubmittedByID INT NULL
            ''')

            conn.commit()

        # Seed system users and routing rules (no sample items/inventory)
        self._seed_system_data()
    
    def _seed_system_data(self):
        """Seed system users, procurement users, and routing rules if empty."""
        with self.get_connection() as conn:
            cursor = conn.cursor()

            # Set Status='Draft' on any PRs that have NULL status
            cursor.execute("UPDATE purchase_requests SET Status = 'Draft' WHERE Status IS NULL")
            conn.commit()

            # Seed users
            cursor.execute('SELECT COUNT(*) FROM users')
            user_count = cursor.fetchone()[0]

            if user_count == 0:
                logger.info("📦 Inserting sample users...")
                sample_users = [
                    ('John Lance', 'Procurement Officer', 50000.00, 'TechCorp Industries,HydroMax Ltd,ChemSupply Co'),
                    ('Sarah Lee', 'General Manager', 500000.00, 'ALL'),
                    ('David Tan', 'Managing Director', 999999.99, 'ALL'),
                ]
                for user in sample_users:
                    cursor.execute('''
                        INSERT INTO users (Name, Role, ApprovalLimit, AssignedSuppliers)
                        VALUES (?, ?, ?, ?)
                    ''', user)
                logger.info("✅ Sample users inserted")
                conn.commit()

            # Seed procurement_users for Role Mapping demo
            cursor.execute('SELECT COUNT(*) FROM procurement_users')
            if cursor.fetchone()[0] == 0:
                logger.info("📦 Inserting procurement users for role mapping...")
                procurement_users = [
                    ('John Lance', 'Senior Procurement Officer', 5000.00,
                     'TechCorp Industries,ChemSupply Co'),
                    ('Sarah Lee', 'General Manager', 50000.00,
                     'ALL'),
                    ('David Tan', 'Managing Director', 100000.00,
                     'ALL'),
                    ('Emily Wong', 'Procurement Executive', 10000.00,
                     'HydroMax Ltd,SafetyFirst Inc,MotorTech Systems'),
                    ('Ahmad Rizal', 'Procurement Officer', 8000.00,
                     'Electronics,Furniture'),
                    ('Lisa Chen', 'Senior Procurement Officer', 25000.00,
                     'Raw Materials,ChemSupply Co,Equipment'),
                    ('Raj Kumar', 'Procurement Executive', 12000.00,
                     'Machinery,MotorTech Systems'),
                    ('Nurul Huda', 'Procurement Officer', 6000.00,
                     'Supplies,Services'),
                ]
                for pu in procurement_users:
                    cursor.execute('''
                        INSERT INTO procurement_users (UserName, Role, ApprovalLimit, AssignedSuppliers)
                        VALUES (?, ?, ?, ?)
                    ''', pu)
                logger.info("✅ Procurement users inserted")
                conn.commit()

            # Set up hierarchy: GM/MD have no approval limits/suppliers, officers report to them
            cursor.execute("UPDATE procurement_users SET ApprovalLimit = 0, AssignedSuppliers = NULL WHERE Role IN ('General Manager', 'Managing Director')")
            cursor.execute("SELECT UserID, Role FROM procurement_users WHERE Role IN ('General Manager', 'Managing Director')")
            sup_rows = cursor.fetchall()
            supervisors = {r[1]: r[0] for r in sup_rows}
            gm_id = supervisors.get('General Manager')
            md_id = supervisors.get('Managing Director')
            if gm_id:
                cursor.execute("UPDATE procurement_users SET ReportsTo = ? WHERE UserName IN ('John Lance', 'Emily Wong', 'Ahmad Rizal', 'Lisa Chen')", (gm_id,))
            if md_id:
                cursor.execute("UPDATE procurement_users SET ReportsTo = ? WHERE UserName IN ('Raj Kumar', 'Nurul Huda')", (md_id,))
            conn.commit()

            # Routing rules table
            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'routing_rules')
                CREATE TABLE [dbo].[routing_rules] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    condition_text NVARCHAR(500) NOT NULL,
                    assign_to NVARCHAR(255) NOT NULL,
                    is_active BIT DEFAULT 1
                )
            ''')
            conn.commit()

            # Seed routing rules
            cursor.execute('SELECT COUNT(*) FROM routing_rules')
            if cursor.fetchone()[0] == 0:
                logger.info("📦 Inserting routing rules...")
                rules = [
                    ('Value > RM 50,000', 'David Tan (Managing Director)', 1),
                    ('Risk Level = Critical', 'Sarah Lee (General Manager)', 1),
                    ('Category = Electronics', 'Ahmad Rizal (Procurement Officer)', 1),
                    ('Category = Machinery', 'Raj Kumar (Procurement Executive)', 1),
                    ('Category = Raw Materials', 'Lisa Chen (Senior Procurement Officer)', 1),
                    ('Supplier = HydroMax Ltd', 'Emily Wong (Procurement Executive)', 1),
                ]
                for rule in rules:
                    cursor.execute('''
                        INSERT INTO routing_rules (condition_text, assign_to, is_active)
                        VALUES (?, ?, ?)
                    ''', rule)
                logger.info("✅ Routing rules inserted")
                conn.commit()

            # ── Seasonality Events (renamed from custom_seasonality_events) ──
            # Migrate: rename old table if it exists
            cursor.execute('''
                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'custom_seasonality_events')
                   AND NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'seasonality_events')
                    EXEC sp_rename 'custom_seasonality_events', 'seasonality_events'
            ''')
            conn.commit()

            cursor.execute('''
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'seasonality_events')
                CREATE TABLE [dbo].[seasonality_events] (
                    id INT IDENTITY(1,1) PRIMARY KEY,
                    name NVARCHAR(255) NOT NULL,
                    description NVARCHAR(500) DEFAULT '',
                    months NVARCHAR(100) NOT NULL,
                    multiplier FLOAT DEFAULT 1.2,
                    category NVARCHAR(50) DEFAULT 'festive',
                    severity NVARCHAR(20) DEFAULT 'medium',
                    is_system BIT DEFAULT 0,
                    created_at DATETIME2 DEFAULT GETDATE(),
                    updated_at DATETIME2 DEFAULT GETDATE()
                )
            ''')
            conn.commit()

            # Add is_system column if missing (migration from old schema)
            cursor.execute('''
                IF NOT EXISTS (
                    SELECT * FROM sys.columns
                    WHERE object_id = OBJECT_ID('seasonality_events') AND name = 'is_system'
                )
                ALTER TABLE seasonality_events ADD is_system BIT DEFAULT 0
            ''')
            conn.commit()

            # Seed built-in seasonality events if table is empty
            self._seed_system_seasonality_events(cursor, conn)

            # Update all Draft POs to Completed
            cursor.execute("UPDATE purchase_orders SET Status = 'Completed' WHERE Status = 'DRAFT' OR Status = 'Draft'")
            conn.commit()

    # ========================================
    # SEASONALITY EVENTS (system + custom)
    # ========================================

    def _seed_system_seasonality_events(self, cursor, conn):
        """Seed built-in SEASON_CALENDAR events into seasonality_events table."""
        from seasonality_service import SEASON_CALENDAR
        cursor.execute('SELECT COUNT(*) FROM seasonality_events WHERE is_system = 1')
        count = cursor.fetchone()[0]
        if count > 0:
            return  # Already seeded

        for name, info in SEASON_CALENDAR.items():
            months_json = json.dumps(info['months'])
            max_mult = max(info['multipliers'].values()) if info['multipliers'] else 1.0
            cursor.execute('''
                INSERT INTO seasonality_events
                    (name, description, months, multiplier, category, severity, is_system)
                VALUES (?, ?, ?, ?, ?, ?, 1)
            ''', (
                name,
                info.get('description', ''),
                months_json,
                round(max_mult, 2),
                info.get('category', 'general'),
                info.get('severity', 'medium'),
            ))
        conn.commit()
        logger.info(f"✅ Seeded {len(SEASON_CALENDAR)} system seasonality events")

    def get_seasonality_events(self) -> List[Dict[str, Any]]:
        """Return all seasonality events (system + custom)."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM seasonality_events ORDER BY is_system DESC, name')
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, r)) for r in cursor.fetchall()]
            for row in rows:
                if isinstance(row.get('months'), str):
                    try:
                        row['months'] = json.loads(row['months'])
                    except (json.JSONDecodeError, TypeError):
                        row['months'] = []
                row['is_system'] = bool(row.get('is_system', 0))
            return rows

    # Backward compat alias
    def get_custom_seasonality_events(self) -> List[Dict[str, Any]]:
        return self.get_seasonality_events()

    def upsert_seasonality_event(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Insert or update a seasonality event."""
        months_json = json.dumps(data.get('months', []))
        is_system = 1 if data.get('is_system') else 0
        with self.get_connection() as conn:
            cursor = conn.cursor()
            event_id = data.get('id')
            if event_id:
                cursor.execute('''
                    UPDATE seasonality_events
                    SET name=?, description=?, months=?, multiplier=?, category=?, severity=?, updated_at=GETDATE()
                    WHERE id=?
                ''', (
                    data.get('name', ''),
                    data.get('description', ''),
                    months_json,
                    data.get('multiplier', 1.2),
                    data.get('category', 'festive'),
                    data.get('severity', 'medium'),
                    event_id,
                ))
            else:
                cursor.execute('''
                    INSERT INTO seasonality_events (name, description, months, multiplier, category, severity, is_system)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    data.get('name', ''),
                    data.get('description', ''),
                    months_json,
                    data.get('multiplier', 1.2),
                    data.get('category', 'festive'),
                    data.get('severity', 'medium'),
                    is_system,
                ))
                cursor.execute('SELECT SCOPE_IDENTITY()')
                row = cursor.fetchone()
                event_id = row[0] if row else None
            conn.commit()
        return {'id': event_id, **data}

    # Backward compat alias
    def upsert_custom_seasonality_event(self, data: Dict[str, Any]) -> Dict[str, Any]:
        return self.upsert_seasonality_event(data)

    def delete_seasonality_event(self, event_id: int) -> bool:
        """Delete a seasonality event by ID."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM seasonality_events WHERE id=?', (event_id,))
            conn.commit()
            return cursor.rowcount > 0

    # Backward compat alias
    def delete_custom_seasonality_event(self, event_id: int) -> bool:
        return self.delete_seasonality_event(event_id)

    def get_seasonality_analysis(self, plan_start: str, plan_end: str) -> Dict[str, Any]:
        """Run seasonality detection on monthly sales history using DB events."""
        from seasonality_service import detect_seasonal_patterns

        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT sku, year, month, sales_qty FROM monthly_sales_history')
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, r)) for r in cursor.fetchall()]

        all_events = self.get_seasonality_events()
        return detect_seasonal_patterns(rows, plan_start, plan_end, db_events=all_events)

    # ========================================
    # INVENTORY SEGMENTATION METHODS
    # ========================================

    def get_inventory_segment(self, sku: str) -> Optional[Dict[str, Any]]:
        """Get segmented inventory for a single SKU."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM inventory_segments WHERE sku = ?', (sku,))
            row = cursor.fetchone()
            if not row:
                return None
            columns = [col[0] for col in cursor.description]
            return dict(zip(columns, row))

    def get_all_inventory_segments(self) -> List[Dict[str, Any]]:
        """Get segmented inventory for all SKUs."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM inventory_segments')
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, r)) for r in cursor.fetchall()]

    def update_inventory_segment(self, sku: str, data: Dict[str, Any]) -> bool:
        """Update segmented inventory fields for a SKU."""
        allowed = [
            'sellable_main_warehouse', 'sellable_tiktok', 'sellable_shopee',
            'sellable_lazada', 'sellable_estore', 'reserved_b2b_projects',
            'sellable_corporate', 'sellable_east_mas', 'sellable_minor_bp',
            'quarantine_sirim', 'quarantine_rework', 'stock_bp', 'stock_dm',
            'quarantine_incomplete', 'stock_mgit',
        ]
        updates = {k: v for k, v in data.items() if k in allowed}
        if not updates:
            return False
        set_clause = ', '.join(f'{k} = ?' for k in updates)
        values = list(updates.values()) + [sku]
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f'UPDATE inventory_segments SET {set_clause} WHERE sku = ?', values)
            if cursor.rowcount > 0:
                self._sync_stock_from_segments(cursor)
                return True
            return False

    @staticmethod
    def _sync_stock_from_segments(cursor):
        """Recalculate items.current_stock from inventory_segments channel totals."""
        cursor.execute('''
            UPDATE items SET current_stock = (
                SELECT COALESCE(
                    s.sellable_main_warehouse + s.sellable_tiktok +
                    s.sellable_shopee + s.sellable_lazada +
                    s.reserved_b2b_projects + s.quarantine_sirim + s.quarantine_rework,
                    items.current_stock
                )
                FROM inventory_segments s WHERE s.sku = items.sku
            )
            WHERE EXISTS (SELECT 1 FROM inventory_segments s WHERE s.sku = items.sku)
        ''')

    def rebuild_items_from_sources(self):
        """Rebuild [dbo].[items] by joining inventory_segments (stock/sales)
        with vendor_master (supplier specs/pricing).
        Called after Xeersoft or vendor master uploads."""
        with self.get_connection() as conn:
            cursor = conn.cursor()

            cursor.execute('DELETE FROM items')

            cursor.execute('''
                INSERT INTO items (
                    sku, product, category, current_stock,
                    sales_last_30_days, sales_last_60_days, sales_last_90_days,
                    unit_price, supplier, lead_time_days, moq, failure_rate,
                    units_per_ctn, cbm_per_ctn, weight_per_ctn,
                    supplier_id
                )
                SELECT
                    seg.sku,
                    COALESCE(NULLIF(seg.product, ''), vm.model, ''),
                    COALESCE(NULLIF(seg.category, ''), vm.primary_category, 'General'),
                    COALESCE(
                        seg.sellable_main_warehouse + seg.sellable_tiktok +
                        seg.sellable_shopee + seg.sellable_lazada +
                        seg.reserved_b2b_projects + seg.quarantine_sirim +
                        seg.quarantine_rework, 0),
                    COALESCE(seg.sales_last_30_days, 0),
                    COALESCE(seg.sales_last_60_days, 0),
                    COALESCE(seg.sales_last_90_days, 0),
                    vm.unit_price,
                    vm.vendor_name,
                    vm.lead_time,
                    vm.moq,
                    vm.failure_rate,
                    vm.units_per_ctn,
                    vm.cbm,
                    vm.weight_kg,
                    seg.supplier_id
                FROM inventory_segments seg
                LEFT JOIN vendor_master vm ON vm.item_code = seg.sku
            ''')

            rebuilt = cursor.rowcount
            conn.commit()
            logger.info(f"Rebuilt items table: {rebuilt} rows from inventory_segments + vendor_master")
            return rebuilt

    # ========================================
    # INCOMING SHIPMENTS (from active POs)
    # ========================================

    def get_incoming_shipments(self, sku: str) -> List[Dict[str, Any]]:
        """Get all in-transit or pending PO lines for a SKU."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT po.PO_ID as po_id,
                       'PO-' + CAST(po.PO_ID AS NVARCHAR) as po_ref,
                       pr.SKU as sku,
                       COALESCE(pr.UserOverriddenQty, pr.AiRecommendedQty) as qty,
                       po.etd_date,
                       po.supplier_confirmed,
                       po.Status as po_status
                FROM purchase_orders po
                JOIN purchase_requests pr ON pr.RequestID = po.RequestID
                WHERE pr.SKU = ?
                  AND po.Status IN ('PENDING_ETD', 'IN_TRANSIT')
            ''', (sku,))
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, r)) for r in cursor.fetchall()]

    # ========================================
    # PO LIFECYCLE METHODS
    # ========================================

    def confirm_po_etd(self, po_id: int, etd_date: str) -> bool:
        """Set ETD and mark supplier as confirmed, move status to IN_TRANSIT."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE purchase_orders
                SET etd_date = ?, supplier_confirmed = 1, Status = 'IN_TRANSIT'
                WHERE PO_ID = ?
            ''', (etd_date, po_id))
            conn.commit()
            return cursor.rowcount > 0

    def mark_po_received(self, po_id: int) -> bool:
        """Mark PO as arrived and increment sellable_main_warehouse stock."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT pr.SKU, COALESCE(pr.UserOverriddenQty, pr.AiRecommendedQty) as qty
                FROM purchase_orders po
                JOIN purchase_requests pr ON pr.RequestID = po.RequestID
                WHERE po.PO_ID = ?
            ''', (po_id,))
            items = cursor.fetchall()
            if not items:
                return False
            cursor.execute('''
                UPDATE purchase_orders
                SET Status = 'ARRIVED', received_date = GETDATE()
                WHERE PO_ID = ?
            ''', (po_id,))
            for row in items:
                cursor.execute('''
                    UPDATE inventory_segments
                    SET sellable_main_warehouse = sellable_main_warehouse + ?
                    WHERE sku = ?
                ''', (row[1], row[0]))
                cursor.execute('''
                    UPDATE items SET current_stock = current_stock + ? WHERE sku = ?
                ''', (row[1], row[0]))
            conn.commit()
            return True

    # ========================================
    # SHIPPING DOCUMENTS METHODS
    # ========================================

    def add_shipping_document(self, po_id: int, doc_type: str, file_url: str) -> Dict[str, Any]:
        """Attach a shipping document to a PO."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO shipping_documents (po_id, doc_type, file_url)
                VALUES (?, ?, ?)
            ''', (po_id, doc_type, file_url))
            cursor.execute('SELECT SCOPE_IDENTITY()')
            new_id = cursor.fetchone()[0]
            conn.commit()
            return {"id": new_id, "po_id": po_id, "doc_type": doc_type, "file_url": file_url}

    def get_shipping_documents(self, po_id: int) -> List[Dict[str, Any]]:
        """Get all shipping documents for a PO."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM shipping_documents WHERE po_id = ?', (po_id,))
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, r)) for r in cursor.fetchall()]

    # ========================================
    # EXTENDED ITEM QUERIES
    # ========================================

    def get_item_extended(self, sku: str) -> Optional[Dict[str, Any]]:
        """Get item with lifecycle, segmented inventory, and incoming shipments."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM items WHERE sku = ?', (sku,))
            row = cursor.fetchone()
            if not row:
                return None
            columns = [col[0] for col in cursor.description]
            result = dict(zip(columns, row))
            result['inventory'] = self.get_inventory_segment(sku)
            result['incoming_shipments'] = self.get_incoming_shipments(sku)
            return result

    def generate_batch_id(self) -> str:
        """Generate unique batch ID"""
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        return f"BATCH-{timestamp}"

    # ========================================
    # 5-STEP WORKFLOW ORCHESTRATION
    # ========================================
    
    def run_ai_procurement_workflow(self, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Execute complete AI procurement workflow
        
        WORKFLOW STEPS:
        1. Get data from database (sample data auto-loaded on first run)
        2. Verify data quality
        3. Send to AI agents (Azure AI Foundry workflow)
        4. Parse AI results
        5. Save to database
        
        Args:
            config: Optional forecast configuration:
                - forecast_period_months: Number of months (default: 3)
                - safety_buffer: Safety stock multiplier (default: 1.2)
                - festival_mode: Enable festival boost (default: False)
                - risk_threshold: Guardian failure rate threshold (default: 3.0)
        
        Returns:
            Complete workflow result with batch ID and summary
        """
        
        batch_id = self.generate_batch_id()
        
        print("\n" + "="*80)
        print(f"🚀 STARTING AI PROCUREMENT WORKFLOW - {batch_id}")
        print("="*80)
        print("Workflow: Database → Verify → AI Agents → Parse → Save")
        print("="*80)
        
        # ======================================
        # STEP 1: Get data from database
        # ======================================
        print("\n📊 STEP 1: Getting data from database...")
        
        items = self.get_items_from_database()
        
        if not items:
            error_msg = "No items found in database"
            logger.error(error_msg)
            return {
                "success": False,
                "error": error_msg,
                "batch_id": batch_id
            }
        
        print(f"✅ Retrieved {len(items)} items from database")
        
        # ======================================
        # STEP 2: Verify data quality
        # ======================================
        print("\n✓ STEP 2: Verifying data quality...")
        
        validation_result = self._validate_items(items)
        
        if not validation_result['valid']:
            error_msg = f"Data validation failed: {validation_result['issues']}"
            logger.error(error_msg)
            return {
                "success": False,
                "error": error_msg,
                "batch_id": batch_id,
                "validation_issues": validation_result['issues']
            }
        
        print(f"✅ Data validation passed: {len(items)} items verified")
        
        if validation_result['warnings']:
            print(f"⚠️  Warnings detected: {len(validation_result['warnings'])}")
            for warning in validation_result['warnings'][:3]:  # Show first 3
                print(f"   - {warning}")
        
        # ======================================
        # STEP 3: Send to AI agents
        # ======================================
        print("\n🤖 STEP 3: Sending to AI agents (Azure AI Foundry)...")
        
        # Prepare configuration
        default_config = {
            "forecast_period_months": 3,
            "safety_buffer": 1.2,
            "festival_mode": False,
            "risk_threshold": 3.0
        }
        if config:
            default_config.update(config)
        
        print(f"   Forecast Period: {default_config['forecast_period_months']} months")
        print(f"   Safety Buffer: {default_config['safety_buffer']}x")
        print(f"   Risk Threshold: {default_config['risk_threshold']}%")
        
        # Prepare data for AI workflow
        agent_input = {
            "batch_id": batch_id,
            "items": items,
            "config": default_config
        }
        
        # Call AI Agent Service (with ML baseline injection)
        try:
            workflow_result = self.agent_service.run_complete_forecast_workflow(agent_input)
            
            if not workflow_result.get("success"):
                error_msg = workflow_result.get("error", "AI workflow failed")
                logger.error(f"❌ AI workflow failed: {error_msg}")
                return {
                    "success": False,
                    "error": error_msg,
                    "batch_id": batch_id,
                    "workflow_result": workflow_result
                }
            
            print(f"\n✅ AI workflow completed successfully")
            print(f"   Execution time: {workflow_result.get('execution_time_seconds', 0):.2f}s")
            
        except Exception as e:
            error_msg = f"AI agent execution failed: {str(e)}"
            logger.error(f"❌ {error_msg}")
            return {
                "success": False,
                "error": error_msg,
                "batch_id": batch_id
            }
        
        # ======================================
        # STEP 4: Parse AI results
        # ======================================
        print("\n📋 STEP 4: Parsing AI agent results...")
        
        forecast_data = self._parse_ai_workflow_results(
            workflow_result=workflow_result,
            items=items,
            config=default_config
        )
        
        print(f"✅ Parsed {forecast_data['total_items']} forecast items")
        print(f"   Critical items: {forecast_data['critical_items']}")
        print(f"   Warning items: {forecast_data['warning_items']}")
        print(f"   Total value: RM {forecast_data['total_value']:,.2f}")
        
        # ======================================
        # STEP 5: Save to database
        # ======================================
        print("\n💾 STEP 5: Saving results to database...")
        
        self._save_forecast_batch(
            batch_id=batch_id,
            config=default_config,
            forecast_data=forecast_data,
            ai_result=json.dumps(workflow_result)
        )

        print(f"Saved batch {batch_id} to database")

        # Also create purchase requests from items
        try:
            pr_result = self.save_forecast_as_purchase_requests({})
            print(f"Created {pr_result['inserted_count']} purchase requests")
        except Exception as e:
            logger.error(f"Error creating purchase requests: {e}")
        
        # ======================================
        # WORKFLOW COMPLETE
        # ======================================
        print("\n" + "="*80)
        print("✅ AI PROCUREMENT WORKFLOW COMPLETED SUCCESSFULLY")
        print("="*80)
        print(f"Batch ID: {batch_id}")
        print(f"Items Processed: {forecast_data['total_items']}")
        print(f"Critical Items: {forecast_data['critical_items']}")
        print(f"Warning Items: {forecast_data['warning_items']}")
        print(f"Total Value: RM {forecast_data['total_value']:,.2f}")
        print(f"AI Execution Time: {workflow_result.get('execution_time_seconds', 0):.2f}s")
        print("="*80 + "\n")
        
        return {
            "success": True,
            "batch_id": batch_id,
            "workflow_status": "completed",
            "items_processed": len(items),
            "summary": forecast_data["summary"],
            "workflow_details": workflow_result
        }
    
    # ========================================
    # STEP 1: GET DATA FROM DATABASE
    # ========================================
    
    def get_items_from_database(self) -> List[Dict[str, Any]]:
        """
        STEP 1: Retrieve all items from database
        
        Returns items as list of dictionaries for AI workflow processing
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM items ORDER BY sku')
            
            columns = [column[0] for column in cursor.description]
            items = []
            
            for row in cursor.fetchall():
                item = dict(zip(columns, row))
                
                # Convert types for JSON serialization (handle NULLs)
                if 'last_updated' in item and item['last_updated']:
                    item['last_updated'] = item['last_updated'].isoformat()
                if 'unit_price' in item:
                    item['unit_price'] = float(item['unit_price']) if item['unit_price'] is not None else None
                if 'failure_rate' in item:
                    item['failure_rate'] = float(item['failure_rate']) if item['failure_rate'] is not None else None
                
                items.append(item)
            
            logger.info(f"📊 Retrieved {len(items)} items from database")
            return items
    
    # ========================================
    # STEP 2: VERIFY DATA QUALITY
    # ========================================
    
    def _validate_items(self, items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        STEP 2: Validate data quality
        
        Checks for:
        - Required fields (SKU, product name)
        - Valid values (positive prices, non-negative stock)
        - Data completeness
        
        Returns validation result with issues and warnings
        """
        issues = []
        warnings = []
        
        for item in items:
            sku = item.get('sku', 'UNKNOWN')
            
            # Critical issues (will fail validation)
            if not item.get('sku'):
                issues.append("Missing SKU for item")
            if not item.get('product'):
                issues.append(f"Missing product name for {sku}")
            if (item.get('current_stock') or 0) < 0:
                issues.append(f"{sku}: Negative stock value")

            # Warnings (won't fail validation)
            if (item.get('unit_price') or 0) <= 0:
                warnings.append(f"{sku}: Unit price is zero or negative")
            if (item.get('moq') or 0) <= 0:
                warnings.append(f"{sku}: Invalid MOQ (minimum order quantity)")
            if not item.get('supplier'):
                warnings.append(f"{sku}: Missing supplier information")
        
        is_valid = len(issues) == 0
        
        if is_valid:
            if warnings:
                logger.warning(f"⚠️ Data validation passed with {len(warnings)} warnings")
            else:
                logger.info(f"✅ Data validation passed: {len(items)} items verified")
        else:
            logger.error(f"❌ Data validation failed: {len(issues)} critical issues found")
        
        return {
            "valid": is_valid,
            "issues": issues,
            "warnings": warnings,
            "items_count": len(items)
        }
    
    # ========================================
    # STEP 4: PARSE AI RESULTS
    # ========================================
    
    def _parse_ai_workflow_results(self, workflow_result: Dict[str, Any], 
                                   items: List[Dict[str, Any]], 
                                   config: Dict[str, Any]) -> Dict[str, Any]:
        """
        STEP 4: Parse AI workflow results into database format
        
        Extracts insights from:
        - Guardian Agent output (quality checks, blocked items)
        - Forecaster Agent output (demand forecasts, festival detection)
        - Logistics Agent output (optimized quantities, shipping)
        
        Returns structured forecast data ready for database
        """
        
        agents_output = workflow_result.get("agents_output", {})
        final_output = workflow_result.get("final_recommendations", "")
        
        # Extract agent outputs
        guardian_output = ""
        forecaster_output = ""
        logistics_output = ""
        
        for agent_data in agents_output.get("agents", []):
            agent_name = agent_data.get("agent", "").lower()
            if "guardian" in agent_name:
                guardian_output = agent_data.get("output", "")
            elif "forecaster" in agent_name or "forecast" in agent_name:
                forecaster_output = agent_data.get("output", "")
            elif "logistics" in agent_name or "logistic" in agent_name:
                logistics_output = agent_data.get("output", "")
        
        # Process each item and extract AI insights
        forecast_items_data = []
        total_value = 0
        critical_items = 0
        warning_items = 0
        
        for item in items:
            sku = item['sku']
            
            # Extract AI insights for this SKU from the output text
            item_insights = self._extract_item_insights(
                sku=sku,
                guardian_text=guardian_output,
                forecaster_text=forecaster_output,
                logistics_text=logistics_output,
                final_output=final_output
            )
            
            # Calculate default values if AI didn't provide specific ones
            forecasted_qty = item_insights.get('forecasted_qty') or \
                           int((item.get('sales_last_30_days') or 0) *
                               config.get('forecast_period_months', 3) *
                               config.get('safety_buffer', 1.2))
            
            moq = item.get('moq') or 50
            optimized_qty = ((forecasted_qty // moq) + 1) * moq if forecasted_qty > 0 else moq
            
            # Override with AI-provided values if available
            if item_insights.get('optimized_qty'):
                optimized_qty = item_insights['optimized_qty']
            
            unit_price = float(item.get('unit_price') or 0)
            line_value = optimized_qty * unit_price

            # Determine risk level
            daily_sales = (item.get('sales_last_30_days') or 0) / 30
            days_coverage = (item.get('current_stock') or 0) / daily_sales if daily_sales > 0 else 999
            lead_time = item.get('lead_time_days') or 14
            
            if days_coverage < lead_time:
                risk_level = 'CRITICAL'
                critical_items += 1
            elif days_coverage < lead_time * 2:
                risk_level = 'WARNING'
                warning_items += 1
            else:
                risk_level = 'LOW'
            
            # Guardian status
            failure_rate = float(item.get('failure_rate') or 0)
            guardian_status = item_insights.get('guardian_status') or \
                            ("BLOCKED" if failure_rate > config.get('risk_threshold', 3.0) else "SAFE")
            guardian_reason = item_insights.get('guardian_reason') or \
                            (f"Failure rate {failure_rate}% exceeds threshold" if guardian_status == "BLOCKED" 
                             else "Quality acceptable")
            
            # Only add items that are not blocked
            if guardian_status == "SAFE":
                total_value += line_value
                
                forecast_items_data.append({
                    'sku': sku,
                    'forecasted_qty': forecasted_qty,
                    'optimized_qty': optimized_qty,
                    'unit_price': unit_price,
                    'line_value': line_value,
                    'risk_level': risk_level,
                    'ai_insight': item_insights.get('ai_insight') or 
                                 f"AI Forecast: {forecasted_qty} units for {config.get('forecast_period_months', 3)} months",
                    'guardian_status': guardian_status,
                    'guardian_reason': guardian_reason,
                    'forecaster_recommendation': item_insights.get('forecaster_recommendation') or
                                                f"Based on {item.get('sales_last_30_days', 0)} units/month trend",
                    'logistics_optimization': item_insights.get('logistics_optimization') or
                                            f"Optimized to MOQ: {moq} units",
                    'festival_boost_applied': item_insights.get('festival_boost', False),
                    'container_optimization': item_insights.get('container_optimization') or 
                                            f"Standard container optimization"
                })
        
        return {
            "total_items": len(forecast_items_data),
            "critical_items": critical_items,
            "warning_items": warning_items,
            "total_value": total_value,
            "forecast_items": forecast_items_data,
            "guardian_report": guardian_output,
            "forecaster_report": forecaster_output,
            "logistics_report": logistics_output,
            "summary": {
                "total_items": len(forecast_items_data),
                "total_value": f"RM {total_value:,.2f}",
                "critical_items": critical_items,
                "warning_items": warning_items,
                "estimated_delivery": (datetime.now() + timedelta(days=14)).strftime('%b %d, %Y'),
                "forecast_period": f"{config.get('forecast_period_months', 3)} months"
            }
        }
    
    def _extract_item_insights(self, sku: str, guardian_text: str, 
                              forecaster_text: str, logistics_text: str,
                              final_output: str) -> Dict[str, Any]:
        """
        Extract AI insights for a specific SKU from agent outputs
        
        Uses text parsing to find SKU-specific recommendations
        """
        insights = {}
        
        # Search for this SKU in the outputs
        all_text = f"{guardian_text}\n{forecaster_text}\n{logistics_text}\n{final_output}"
        
        # Try to extract quantities (look for patterns like "SKU-E001: 150 units")
        qty_pattern = rf"{sku}[:\s]+(\d+)\s*units?"
        qty_match = re.search(qty_pattern, all_text, re.IGNORECASE)
        if qty_match:
            insights['forecasted_qty'] = int(qty_match.group(1))
        
        # Extract guardian status
        if sku in guardian_text:
            if "BLOCKED" in guardian_text.upper() or "REJECT" in guardian_text.upper():
                insights['guardian_status'] = "BLOCKED"
                insights['guardian_reason'] = "Blocked by Guardian due to quality concerns"
            else:
                insights['guardian_status'] = "SAFE"
                insights['guardian_reason'] = "Approved by Guardian quality check"
        
        # Extract festival boost detection
        if "festival" in all_text.lower() and sku in all_text:
            insights['festival_boost'] = True
        
        return insights
    
    # ========================================
    # STEP 5: SAVE TO DATABASE
    # ========================================
    
    def _save_forecast_batch(self, batch_id: str, config: Dict[str, Any], 
                            forecast_data: Dict[str, Any], ai_result: str):
        """
        STEP 5: Save AI forecast results to database
        
        Saves:
        - Batch header (forecast_batches table)
        - Individual forecast items (forecast_items table)
        - AI workflow result (for audit trail)
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # Save batch header
            cursor.execute('''
                INSERT INTO forecast_batches 
                (batch_id, config_json, total_items, total_value, critical_items, warning_items, 
                 status, ai_workflow_result)
                VALUES (?, ?, ?, ?, ?, ?, 'PENDING_APPROVAL', ?)
            ''', (
                batch_id, 
                json.dumps(config), 
                forecast_data["total_items"],
                forecast_data["total_value"],
                forecast_data["critical_items"],
                forecast_data["warning_items"],
                ai_result
            ))
            
            # Save forecast items
            for item in forecast_data["forecast_items"]:
                cursor.execute('''
                    INSERT INTO forecast_items 
                    (batch_id, sku, forecasted_qty, optimized_qty, unit_price, line_value, 
                     risk_level, ai_insight, guardian_status, guardian_reason, 
                     forecaster_recommendation, logistics_optimization, 
                     festival_boost_applied, container_optimization)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    batch_id, 
                    item['sku'], 
                    item['forecasted_qty'],
                    item['optimized_qty'], 
                    item['unit_price'], 
                    item['line_value'],
                    item['risk_level'], 
                    item['ai_insight'],
                    item['guardian_status'],
                    item['guardian_reason'],
                    item['forecaster_recommendation'],
                    item['logistics_optimization'],
                    item.get('festival_boost_applied', False),
                    item.get('container_optimization')
                ))
            
            # Log agent execution
            cursor.execute('''
                INSERT INTO agent_execution_log 
                (batch_id, agent_name, status, output_data)
                VALUES (?, ?, ?, ?)
            ''', (
                batch_id,
                "COMPLETE_WORKFLOW",
                "completed",
                ai_result
            ))
            
            conn.commit()
            logger.info(f"✅ Saved batch {batch_id} to database")
    
    # ========================================
    # DATA RETRIEVAL METHODS
    # ========================================
    
    def get_batch_detail(self, batch_id: str) -> Dict[str, Any]:
        """Get complete batch detail from database"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute('SELECT * FROM forecast_batches WHERE batch_id = ?', (batch_id,))
            batch_row = cursor.fetchone()
            
            if not batch_row:
                return {"error": "Batch not found"}
            
            batch_columns = [column[0] for column in cursor.description]
            batch = dict(zip(batch_columns, batch_row))
            
            # Get items
            cursor.execute('''
                SELECT 
                    fi.sku,
                    i.product,
                    i.category,
                    fi.forecasted_qty,
                    fi.optimized_qty,
                    fi.unit_price,
                    fi.line_value,
                    fi.risk_level,
                    fi.ai_insight,
                    fi.guardian_status,
                    fi.guardian_reason,
                    fi.forecaster_recommendation,
                    fi.logistics_optimization
                FROM forecast_items fi
                JOIN items i ON fi.sku = i.sku
                WHERE fi.batch_id = ?
                ORDER BY fi.risk_level DESC, fi.line_value DESC
            ''', (batch_id,))
            
            item_columns = [column[0] for column in cursor.description]
            items = []
            
            for row in cursor.fetchall():
                item = dict(zip(item_columns, row))
                item['unit_price'] = float(item['unit_price'])
                item['line_value'] = float(item['line_value'])
                items.append(item)
            
            batch['items'] = items
            batch['total_value'] = float(batch['total_value'])
            
            return batch
    
    def get_all_batches(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get all batches from database"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute(f'''
                SELECT TOP {limit}
                    batch_id,
                    CONVERT(VARCHAR(19), created_date, 120) as created_date,
                    created_by,
                    total_items,
                    total_value,
                    critical_items,
                    warning_items,
                    status
                FROM forecast_batches
                ORDER BY created_date DESC
            ''')
            
            columns = [column[0] for column in cursor.description]
            batches = []
            
            for row in cursor.fetchall():
                batch = dict(zip(columns, row))
                batch['total_value'] = float(batch['total_value'])
                batches.append(batch)
            
            return batches

    # ========================================
    # COMPATIBILITY: get_items() alias
    # ========================================

    def get_items(self) -> List[Dict[str, Any]]:
        """Alias for get_items_from_database — required by main.py startup"""
        return self.get_items_from_database()

    # ========================================
    # PURCHASE REQUESTS
    # ========================================

    def _ensure_container_logistics(self, row: dict) -> dict:
        """Compute container logistics fields using per-item dimensions from items table."""
        if row.get('ContainerFillRate') and row['ContainerFillRate'] > 0:
            return row
        qty = row.get('AiRecommendedQty') or row.get('UserOverriddenQty') or 0
        if qty <= 0:
            return row

        # Look up per-item dimensions
        units_per_ctn = 1
        cbm_per_ctn = 0.05
        weight_per_ctn = 10.0
        sku = row.get('SKU', '')
        if sku:
            try:
                with self.get_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute('SELECT units_per_ctn, cbm_per_ctn, weight_per_ctn FROM items WHERE sku = ?', (sku,))
                    item_row = cursor.fetchone()
                    if item_row:
                        units_per_ctn = item_row[0] or 1
                        cbm_per_ctn = float(item_row[1] or 0.05)
                        weight_per_ctn = float(item_row[2] or 10.0)
            except Exception:
                pass

        from logistics_constants import calculate_full_logistics
        cartons = math.ceil(qty / units_per_ctn)
        total_cbm = round(cartons * cbm_per_ctn, 2)
        total_weight = round(cartons * weight_per_ctn, 2)

        logistics = calculate_full_logistics(total_cbm, total_weight)
        lead_time = row.get('SupplierLeadTime') or 14

        row['TotalCBM'] = total_cbm
        row['TotalWeightKg'] = total_weight
        row['LogisticsVehicle'] = logistics["container_size"]
        row['ContainerStrategy'] = logistics["strategy"]
        row['ContainerFillRate'] = int(logistics["container_utilization_pct"])
        row['EstimatedTransitDays'] = row.get('EstimatedTransitDays') or (lead_time + (14 if logistics["strategy"] != 'Local Bulk' else 0))
        row['ContainerSize'] = logistics["container_size"]
        row['ContainerCount'] = logistics["container_count"]
        row['RecommendedLorry'] = logistics["recommended_lorry"]
        row['LorryCount'] = logistics["lorry_count"]
        row['FillUpSuggestion'] = logistics["fill_up_suggestion"]
        row['WeightUtilizationPct'] = int(logistics["weight_utilization_pct"])
        row['SpareCbm'] = logistics["spare_cbm"]
        return row

    def update_item_packaging(self, sku: str, units_per_ctn=None, cbm_per_ctn=None, weight_per_ctn=None):
        """Update packaging dimensions for a single item."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE items SET
                    units_per_ctn = COALESCE(?, units_per_ctn),
                    cbm_per_ctn = COALESCE(?, cbm_per_ctn),
                    weight_per_ctn = COALESCE(?, weight_per_ctn)
                WHERE sku = ?
            ''', (units_per_ctn, cbm_per_ctn, weight_per_ctn, sku))

    def update_item_supplier_info(self, sku: str, supplier_name=None, lead_time_days=None,
                                   moq=None, failure_rate=None, supplier_id_code=None):
        """Update supplier-enriched fields for a single item from vendor master."""
        self.batch_update_item_supplier_info([{
            'sku': sku, 'supplier_name': supplier_name, 'lead_time_days': lead_time_days,
            'moq': moq, 'failure_rate': failure_rate, 'supplier_id_code': supplier_id_code,
        }])

    def batch_update_item_supplier_info(self, updates: list):
        """Batch update supplier-enriched fields for multiple items in a single connection."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            # Build supplier_code -> id cache
            codes = set(u.get('supplier_id_code', '') for u in updates if u.get('supplier_id_code'))
            sid_cache = {}
            for code in codes:
                cursor.execute('SELECT id FROM suppliers WHERE UPPER(supplier_code) = ?', (code.upper(),))
                row = cursor.fetchone()
                if row:
                    sid_cache[code.upper()] = row[0]
            for u in updates:
                sid = sid_cache.get((u.get('supplier_id_code') or '').upper())
                cursor.execute('''
                    UPDATE items SET
                        supplier = COALESCE(NULLIF(?, ''), supplier),
                        lead_time_days = COALESCE(?, lead_time_days),
                        moq = COALESCE(?, moq),
                        failure_rate = COALESCE(?, failure_rate),
                        unit_price = COALESCE(?, unit_price),
                        supplier_id = COALESCE(?, supplier_id)
                    WHERE sku = ?
                ''', (u.get('supplier_name'), u.get('lead_time_days'), u.get('moq'),
                      u.get('failure_rate'), u.get('unit_price'), sid, u['sku']))

    def get_purchase_requests(self, risk_level=None, category=None, status=None, **kwargs):
        """Get purchase requests with optional risk_level and status filters"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            query = 'SELECT * FROM purchase_requests WHERE 1=1'
            params = []
            if risk_level and risk_level.upper() != 'ALL':
                query += ' AND UPPER(RiskLevel) = UPPER(?)'
                params.append(risk_level)
            if status:
                query += ' AND Status = ?'
                params.append(status)
            query += ''' ORDER BY
                CASE UPPER(RiskLevel)
                    WHEN 'CRITICAL' THEN 0
                    WHEN 'WARNING' THEN 1
                    ELSE 2
                END, TotalValue DESC'''
            cursor.execute(query, params)
            columns = [col[0] for col in cursor.description]
            rows = []
            for row in cursor.fetchall():
                item = dict(zip(columns, row))
                if 'TotalValue' in item and item['TotalValue'] is not None:
                    item['TotalValue'] = float(item['TotalValue'])
                rows.append(self._ensure_container_logistics(item))
            return {"requests": rows, "total_count": len(rows)}

    def get_purchase_request_detail(self, request_id, **kwargs):
        """Get single purchase request by RequestID"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM purchase_requests WHERE RequestID = ?', (request_id,))
            row = cursor.fetchone()
            if not row:
                return {"error": "Request not found", "request_id": request_id}
            columns = [col[0] for col in cursor.description]
            result = dict(zip(columns, row))
            if 'TotalValue' in result and result['TotalValue'] is not None:
                result['TotalValue'] = float(result['TotalValue'])
            return self._ensure_container_logistics(result)

    def override_recommendation(self, request_id=None, quantity=None,
                                reason_category=None, additional_details=None,
                                sku=None, **kwargs):
        """Update UserOverriddenQty and reason on a purchase request"""
        lookup_id = request_id
        with self.get_connection() as conn:
            cursor = conn.cursor()
            if lookup_id is None and sku is not None:
                cursor.execute('SELECT RequestID FROM purchase_requests WHERE SKU = ?', (sku,))
                row = cursor.fetchone()
                if row:
                    lookup_id = row[0]
            if lookup_id is None:
                return {"success": False, "error": "No request_id or sku provided"}

            cursor.execute('''
                UPDATE purchase_requests
                SET UserOverriddenQty = ?,
                    OverrideReason = ?,
                    OverrideDetails = ?,
                    LastModified = GETDATE()
                WHERE RequestID = ?
            ''', (quantity, reason_category, additional_details, lookup_id))

            if cursor.rowcount == 0:
                return {"success": False, "error": "Request not found"}

            conn.commit()
            return {
                "success": True,
                "message": "Override saved",
                "request_id": lookup_id,
                "new_quantity": quantity,
                "reason": reason_category
            }

    # ========================================
    # XEERSOFT INGESTION
    # ========================================

    def ingest_xeersoft_data(self, processed_data: Dict[str, Any]) -> Dict[str, Any]:
        """Ingest cleaned Xeersoft data into items, inventory_segments, and monthly_sales_history."""
        items = processed_data.get('items', [])
        inventory = processed_data.get('inventory', [])
        monthly_sales = processed_data.get('monthly_sales', [])

        items_upserted = 0
        inv_upserted = 0
        sales_records = 0

        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.fast_executemany = True

            # ── Resolve supplier_id and supplier_name from supplier_code ──
            supplier_cache = {}      # code -> id
            supplier_name_cache = {} # code -> name
            for item in items:
                vc = item.get('supplier_code', '')
                if vc and vc not in supplier_cache:
                    cursor.execute('SELECT id, name FROM suppliers WHERE UPPER(supplier_code) = ?', (vc.upper(),))
                    row = cursor.fetchone()
                    if row:
                        supplier_cache[vc] = row[0]
                        supplier_name_cache[vc] = row[1]
                    else:
                        cursor.execute(
                            "INSERT INTO suppliers (supplier_code, name) VALUES (?, ?)",
                            (vc.upper(), f"Supplier {vc}")
                        )
                        cursor.execute("SELECT SCOPE_IDENTITY()")
                        supplier_cache[vc] = cursor.fetchone()[0]
                        supplier_name_cache[vc] = f"Supplier {vc}"

            # ── Upsert inventory segments (with product/category/sales) ──
            # Items table is no longer written directly — it's rebuilt from
            # inventory_segments + vendor_master via rebuild_items_from_sources().
            items_upserted = len(items)

            # ── Build item lookup for product/category/sales ──
            item_lookup = {it['sku']: it for it in items}

            # ── Upsert inventory segments (with product/category/sales) ──
            if inventory:
                for inv in inventory:
                    vid = supplier_cache.get(inv.get('supplier_code', ''))
                    it = item_lookup.get(inv['sku'], {})
                    cursor.execute('''
                        MERGE inventory_segments AS target
                        USING (SELECT ? AS sku) AS source ON target.sku = source.sku
                        WHEN MATCHED THEN UPDATE SET
                            product = ?, category = ?,
                            sellable_main_warehouse = ?, sellable_tiktok = ?,
                            sellable_shopee = ?, sellable_lazada = ?,
                            reserved_b2b_projects = ?, quarantine_sirim = ?,
                            quarantine_rework = ?,
                            sellable_estore = ?, sellable_corporate = ?,
                            sellable_east_mas = ?, sellable_minor_bp = ?,
                            stock_bp = ?, stock_dm = ?,
                            quarantine_incomplete = ?, stock_mgit = ?,
                            sales_last_30_days = ?, sales_last_60_days = ?, sales_last_90_days = ?,
                            supplier_id = COALESCE(?, target.supplier_id)
                        WHEN NOT MATCHED THEN INSERT
                            (sku, product, category,
                             sellable_main_warehouse, sellable_tiktok, sellable_shopee,
                             sellable_lazada, reserved_b2b_projects, quarantine_sirim, quarantine_rework,
                             sellable_estore, sellable_corporate, sellable_east_mas, sellable_minor_bp,
                             stock_bp, stock_dm, quarantine_incomplete, stock_mgit,
                             sales_last_30_days, sales_last_60_days, sales_last_90_days,
                             supplier_id)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    ''', (
                        inv['sku'],
                        it.get('product', ''), it.get('category', 'General'),
                        inv.get('sellable_main_warehouse', 0), inv.get('sellable_tiktok', 0),
                        inv.get('sellable_shopee', 0), inv.get('sellable_lazada', 0),
                        inv.get('reserved_b2b_projects', 0), inv.get('quarantine_sirim', 0),
                        inv.get('quarantine_rework', 0),
                        inv.get('sellable_estore', 0), inv.get('sellable_corporate', 0),
                        inv.get('sellable_east_mas', 0), inv.get('sellable_minor_bp', 0),
                        inv.get('stock_bp', 0), inv.get('stock_dm', 0),
                        inv.get('quarantine_incomplete', 0), inv.get('stock_mgit', 0),
                        it.get('sales_last_30_days', 0), it.get('sales_last_60_days', 0),
                        it.get('sales_last_90_days', 0), vid,
                        inv['sku'],
                        it.get('product', ''), it.get('category', 'General'),
                        inv.get('sellable_main_warehouse', 0), inv.get('sellable_tiktok', 0),
                        inv.get('sellable_shopee', 0), inv.get('sellable_lazada', 0),
                        inv.get('reserved_b2b_projects', 0), inv.get('quarantine_sirim', 0),
                        inv.get('quarantine_rework', 0),
                        inv.get('sellable_estore', 0), inv.get('sellable_corporate', 0),
                        inv.get('sellable_east_mas', 0), inv.get('sellable_minor_bp', 0),
                        inv.get('stock_bp', 0), inv.get('stock_dm', 0),
                        inv.get('quarantine_incomplete', 0), inv.get('stock_mgit', 0),
                        it.get('sales_last_30_days', 0), it.get('sales_last_60_days', 0),
                        it.get('sales_last_90_days', 0), vid,
                    ))
                inv_upserted = len(inventory)

            # ── Upsert monthly sales history (batch) ──
            if monthly_sales:
                sales_params = [(sku, year, month, qty, sku, year, month, qty)
                                for sku, year, month, qty in monthly_sales]
                cursor.executemany('''
                    MERGE monthly_sales_history AS target
                    USING (SELECT ? AS sku, ? AS year, ? AS month) AS source
                        ON target.sku = source.sku AND target.year = source.year AND target.month = source.month
                    WHEN MATCHED THEN UPDATE SET sales_qty = ?
                    WHEN NOT MATCHED THEN INSERT (sku, year, month, sales_qty) VALUES (?, ?, ?, ?);
                ''', sales_params)
                sales_records = len(monthly_sales)

            conn.commit()

        # Rebuild items table from inventory_segments + vendor_master
        self.rebuild_items_from_sources()

        logger.info(f"Xeersoft ingestion: {items_upserted} items, {inv_upserted} inventory, {sales_records} sales records")
        return {
            'items_upserted': items_upserted,
            'inventory_upserted': inv_upserted,
            'sales_records': sales_records,
        }

    # ========================================
    # SUPPLIER LISTING
    # ========================================

    def get_all_suppliers(self) -> list:
        """Get all suppliers with item counts and key details."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT s.id, s.supplier_code, s.name, s.contact_person, s.email, s.phone,
                       s.standard_lead_time_days, s.currency, s.payment_terms, s.address,
                       s.created_date, s.last_updated,
                       COUNT(vm.id) AS item_count,
                       COALESCE(SUM(vm.unit_price), 0) AS total_catalog_value,
                       STRING_AGG(vm.primary_category, ', ') AS categories
                FROM suppliers s
                LEFT JOIN vendor_master vm ON UPPER(vm.supplier_id_code) = UPPER(s.supplier_code)
                GROUP BY s.id, s.supplier_code, s.name, s.contact_person, s.email, s.phone,
                         s.standard_lead_time_days, s.currency, s.payment_terms, s.address,
                         s.created_date, s.last_updated
                ORDER BY s.name
            ''')
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            results = []
            for row in rows:
                d = dict(zip(columns, row))
                # Deduplicate categories
                cats = d.get('categories') or ''
                unique_cats = list(dict.fromkeys([c.strip() for c in cats.split(',') if c.strip()]))
                d['categories'] = ', '.join(unique_cats) if unique_cats else 'Uncategorized'
                d['created_date'] = str(d['created_date']) if d.get('created_date') else None
                d['last_updated'] = str(d['last_updated']) if d.get('last_updated') else None
                results.append(d)
            return results

    def get_supplier_detail(self, supplier_id: int) -> dict:
        """Get supplier details with all their items from vendor_master."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT id, supplier_code, name, contact_person, email, phone,
                       standard_lead_time_days, currency, payment_terms, address,
                       created_date, last_updated
                FROM suppliers WHERE id = ?
            ''', (supplier_id,))
            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                return {"error": "Supplier not found"}
            supplier = dict(zip(columns, row))
            supplier['created_date'] = str(supplier['created_date']) if supplier.get('created_date') else None
            supplier['last_updated'] = str(supplier['last_updated']) if supplier.get('last_updated') else None

            # Get items from vendor_master
            cursor.execute('''
                SELECT vm.id, vm.item_code, vm.model, vm.primary_category,
                       vm.unit_price, vm.currency, vm.moq, vm.lead_time,
                       vm.units_per_ctn, vm.cbm, vm.weight_kg, vm.status,
                       vm.payment_terms, vm.failure_rate
                FROM vendor_master vm
                WHERE UPPER(vm.supplier_id_code) = UPPER(?)
                ORDER BY vm.item_code
            ''', (supplier.get('supplier_code', ''),))
            item_cols = [col[0] for col in cursor.description]
            item_rows = cursor.fetchall()
            supplier['items'] = [dict(zip(item_cols, r)) for r in item_rows]

            return supplier

    # ========================================
    # SUPPLIER MASTER INGESTION
    # ========================================

    def upsert_suppliers(self, suppliers: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Upsert supplier records. Matches on supplier_code or name (case-insensitive)."""
        added = 0
        updated = 0
        with self.get_connection() as conn:
            cursor = conn.cursor()
            for v in suppliers:
                # Match by supplier_code first, then by name
                existing = None
                s_code = v.get('supplier_code', '')
                if s_code:
                    cursor.execute(
                        'SELECT id FROM suppliers WHERE UPPER(supplier_code) = UPPER(?)',
                        (s_code,)
                    )
                    existing = cursor.fetchone()
                if not existing:
                    cursor.execute(
                        'SELECT id FROM suppliers WHERE LOWER(name) = LOWER(?)',
                        (v['name'],)
                    )
                    existing = cursor.fetchone()

                if existing:
                    cursor.execute('''
                        UPDATE suppliers SET
                            supplier_id = ?, contact_person = ?, email = ?,
                            phone = ?, standard_lead_time_days = ?,
                            currency = ?, payment_terms = ?, address = ?,
                            supplier_code = COALESCE(NULLIF(?, ''), supplier_code),
                            name = COALESCE(NULLIF(?, ''), name),
                            last_updated = GETDATE()
                        WHERE id = ?
                    ''', (
                        v['supplier_id'], v['contact_person'], v['email'],
                        v['phone'], v['standard_lead_time_days'],
                        v['currency'], v['payment_terms'], v['address'],
                        s_code, v['name'],
                        existing[0],
                    ))
                    updated += 1
                else:
                    cursor.execute('''
                        INSERT INTO suppliers
                            (supplier_id, name, contact_person, email, phone,
                             standard_lead_time_days, currency, payment_terms, address,
                             supplier_code)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        v['supplier_id'], v['name'], v['contact_person'],
                        v['email'], v['phone'], v['standard_lead_time_days'],
                        v['currency'], v['payment_terms'], v['address'],
                        s_code,
                    ))
                    added += 1
        logger.info(f"Supplier upsert: {added} added, {updated} updated")
        return {'added': added, 'updated': updated}

    def upsert_vendor_master(self, rows: list) -> Dict[str, Any]:
        """Upsert all rows from vendor_master.xlsx into vendor_master table.
        Each row is keyed by item_code (MERGE on item_code)."""
        upserted = 0
        with self.get_connection() as conn:
            cursor = conn.cursor()
            for r in rows:
                cursor.execute('''
                    MERGE vendor_master AS target
                    USING (SELECT ? AS item_code) AS source ON target.item_code = source.item_code
                    WHEN MATCHED THEN UPDATE SET
                        model = ?, supplier_id_code = ?, vendor_name = ?,
                        contact_person = ?, email = ?, phone = ?,
                        primary_category = ?, lead_time = ?, currency = ?,
                        payment_terms = ?, moq = ?, status = ?,
                        units_per_ctn = ?, cbm = ?, weight_kg = ?,
                        failure_rate = ?, unit_price = ?,
                        last_updated = GETDATE()
                    WHEN NOT MATCHED THEN INSERT
                        (item_code, model, supplier_id_code, vendor_name,
                         contact_person, email, phone, primary_category,
                         lead_time, currency, payment_terms, moq, status,
                         units_per_ctn, cbm, weight_kg, failure_rate, unit_price)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                ''', (
                    r['item_code'],
                    r['model'], r['supplier_id_code'], r['vendor_name'],
                    r['contact_person'], r['email'], r['phone'],
                    r['primary_category'], r['lead_time'], r['currency'],
                    r['payment_terms'], r['moq'], r['status'],
                    r['units_per_ctn'], r['cbm'], r['weight_kg'],
                    r['failure_rate'], r['unit_price'],
                    r['item_code'],
                    r['model'], r['supplier_id_code'], r['vendor_name'],
                    r['contact_person'], r['email'], r['phone'],
                    r['primary_category'], r['lead_time'], r['currency'],
                    r['payment_terms'], r['moq'], r['status'],
                    r['units_per_ctn'], r['cbm'], r['weight_kg'],
                    r['failure_rate'], r['unit_price'],
                ))
                upserted += 1
        logger.info(f"Vendor master upsert: {upserted} rows")
        return {'upserted': upserted}

    # ========================================
    # DASHBOARD METHODS
    # ========================================

    def get_officer_dashboard(self) -> Dict[str, Any]:
        """Officer dashboard with real DB counts and activity"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            # Core stats
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status IN ('Draft', 'Pending')")
            pending_prs = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE UPPER(RiskLevel) = 'CRITICAL'")
            critical_items = cursor.fetchone()[0]
            cursor.execute("SELECT COALESCE(SUM(TotalValue), 0) FROM purchase_requests WHERE Status IN ('Draft', 'Pending')")
            total_value = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_orders")
            active_pos = cursor.fetchone()[0]

            # Risk breakdown
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE UPPER(RiskLevel) = 'WARNING'")
            warning_items = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE UPPER(RiskLevel) = 'LOW'")
            low_risk_items = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Approved'")
            approved_count = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_requests")
            total_items = cursor.fetchone()[0]

            # Recent activity: approved items, generated POs, submitted batches
            recent_activity = []
            # Recent approvals
            cursor.execute("""
                SELECT TOP 3 SKU, ProductName, Status, ApprovalDate
                FROM purchase_requests
                WHERE Status = 'Approved' AND ApprovalDate IS NOT NULL
                ORDER BY ApprovalDate DESC
            """)
            for row in cursor.fetchall():
                recent_activity.append({
                    'action': f'{row[1]} ({row[0]}) approved',
                    'timestamp': str(row[3]) if row[3] else '',
                    'type': 'approval',
                })
            # Recent POs
            cursor.execute("""
                SELECT TOP 3 PO_ID, SupplierName, TotalAmount, OrderDate, Status
                FROM purchase_orders
                ORDER BY PO_ID DESC
            """)
            for row in cursor.fetchall():
                po_status = row[4] or 'Generated'
                recent_activity.append({
                    'action': f'PO-{row[0]:04d} to {row[1]} - RM {float(row[2] or 0):,.0f} ({po_status})',
                    'timestamp': str(row[3]) if row[3] else '',
                    'type': 'po',
                })
            # Recent batch submissions
            cursor.execute("""
                SELECT TOP 2 batch_id, total_items, total_value, created_date
                FROM forecast_batches
                ORDER BY created_date DESC
            """)
            for row in cursor.fetchall():
                recent_activity.append({
                    'action': f'Batch {row[0]} submitted ({row[1]} items, RM {float(row[2] or 0):,.0f})',
                    'timestamp': str(row[3]) if row[3] else '',
                    'type': 'batch',
                })
            # Sort by timestamp desc, take top 5
            recent_activity.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
            recent_activity = recent_activity[:5]

            # Critical alerts: critical items still pending
            critical_alerts = []
            cursor.execute("""
                SELECT TOP 5 SKU, ProductName, TotalValue, StockCoverageDays
                FROM purchase_requests
                WHERE UPPER(RiskLevel) = 'CRITICAL' AND Status IN ('Draft', 'Pending')
                ORDER BY TotalValue DESC
            """)
            for row in cursor.fetchall():
                coverage = int(row[3]) if row[3] is not None else 0
                critical_alerts.append(
                    f'{row[1]} ({row[0]}) — {coverage} days stock left, RM {float(row[2] or 0):,.0f}'
                )

            # Top suppliers by pending value
            top_suppliers = []
            cursor.execute("""
                SELECT TOP 5 SupplierName, COUNT(*) as item_count,
                       SUM(TotalValue) as total_val
                FROM purchase_requests
                WHERE Status IN ('Draft', 'Pending') AND SupplierName IS NOT NULL
                GROUP BY SupplierName
                ORDER BY SUM(TotalValue) DESC
            """)
            for row in cursor.fetchall():
                top_suppliers.append({
                    'name': row[0],
                    'items': row[1],
                    'value': f'RM {float(row[2] or 0):,.0f}',
                })

            return {
                'stats': {
                    'pending_prs': pending_prs,
                    'critical_items': critical_items,
                    'total_value': f'RM {float(total_value):,.2f}',
                    'active_pos': active_pos,
                    'warning_items': warning_items,
                    'low_risk_items': low_risk_items,
                    'approved_count': approved_count,
                    'total_items': total_items,
                },
                'recent_activity': recent_activity,
                'critical_alerts': critical_alerts,
                'top_suppliers': top_suppliers,
            }

    def get_approver_dashboard(self) -> Dict[str, Any]:
        """Approver dashboard with real DB counts and pending batches"""
        with self.get_connection() as conn:
            cursor = conn.cursor()

            # Pending batches (source of truth for GM)
            pending_batches = []
            cursor.execute("""
                SELECT batch_id, total_items, total_value, created_date, status,
                       critical_items, warning_items
                FROM forecast_batches
                WHERE status = 'PENDING_APPROVAL'
                ORDER BY created_date DESC
            """)
            total_pending_items = 0
            total_pending_value = 0.0
            total_critical_in_batches = 0
            for row in cursor.fetchall():
                items = row[1] or 0
                val = float(row[2] or 0)
                total_pending_items += items
                total_pending_value += val
                total_critical_in_batches += (row[5] or 0)
                pending_batches.append({
                    'batch_id': row[0],
                    'item_count': items,
                    'total_value': f'RM {val:,.0f}',
                    'created_date': str(row[3]) if row[3] else '',
                    'status': row[4],
                    'critical_items': row[5] or 0,
                    'warning_items': row[6] or 0,
                })

            # Also count PRs with Status='Pending' (submitted via approval workflow)
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Pending'")
            pending_pr_count = cursor.fetchone()[0]
            cursor.execute("SELECT COALESCE(SUM(TotalValue), 0) FROM purchase_requests WHERE Status = 'Pending'")
            pending_pr_value = float(cursor.fetchone()[0])

            # Use the higher of batch-based or PR-based pending counts
            pending_count = len(pending_batches) if pending_batches else pending_pr_count
            pending_value = total_pending_value if total_pending_value > 0 else pending_pr_value
            critical_pending = total_critical_in_batches

            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Approved' AND CAST(ApprovalDate AS DATE) = CAST(GETDATE() AS DATE)")
            approved_today = cursor.fetchone()[0]

            # Extra stats
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Approved'")
            total_approved = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Rejected'")
            total_rejected = cursor.fetchone()[0]
            cursor.execute("SELECT COALESCE(SUM(TotalValue), 0) FROM purchase_requests WHERE Status = 'Approved'")
            approved_value = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM purchase_orders")
            total_pos = cursor.fetchone()[0]

            # Recent decisions
            recent_decisions = []
            cursor.execute("""
                SELECT TOP 5 SKU, ProductName, Status, ApprovalDate,
                       TotalValue, RiskLevel
                FROM purchase_requests
                WHERE Status IN ('Approved', 'Rejected') AND ApprovalDate IS NOT NULL
                ORDER BY ApprovalDate DESC
            """)
            for row in cursor.fetchall():
                recent_decisions.append({
                    'sku': row[0],
                    'product': row[1],
                    'decision': row[2],
                    'date': str(row[3]) if row[3] else '',
                    'value': f'RM {float(row[4] or 0):,.0f}',
                    'risk': row[5] or 'Low',
                })

            # Spending by risk
            risk_breakdown = []
            cursor.execute("""
                SELECT UPPER(RiskLevel) as risk, COUNT(*) as cnt,
                       COALESCE(SUM(TotalValue), 0) as val
                FROM purchase_requests
                WHERE Status IN ('Draft', 'Pending')
                GROUP BY UPPER(RiskLevel)
            """)
            for row in cursor.fetchall():
                risk_breakdown.append({
                    'risk': row[0] or 'LOW',
                    'count': row[1],
                    'value': f'RM {float(row[2] or 0):,.0f}',
                })

            return {
                'stats': {
                    'pending_approvals': pending_count,
                    'total_pending_value': f'RM {pending_value:,.2f}',
                    'total_pending_items': total_pending_items,
                    'approved_today': approved_today,
                    'critical_items': critical_pending,
                    'total_approved': total_approved,
                    'total_rejected': total_rejected,
                    'approved_value': f'RM {float(approved_value):,.2f}',
                    'total_pos': total_pos,
                },
                'pending_batches': pending_batches,
                'recent_decisions': recent_decisions,
                'risk_breakdown': risk_breakdown,
            }

    # ========================================
    # STUB METHODS (compatibility with main.py)
    # ========================================

    def accept_all_recommendations(self, *args, **kwargs):
        return {"success": True, "batch_id": self.generate_batch_id()}

    def get_batch_list(self):
        return {"batches": self.get_all_batches()}

    def get_batch_status(self, batch_id):
        return {"batch_id": batch_id, "status": "PENDING"}

    def get_batch_summary(self, batch_id):
        return {"batch_id": batch_id}

    def approve_batch(self, *args, **kwargs):
        return {"success": True}

    def reject_batch(self, *args, **kwargs):
        return {"success": True}

    def get_purchase_orders(self):
        """Get all purchase orders with PR details (supports grouped POs)"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT po.PO_ID, po.RequestID, po.RequestIDs, po.SupplierName, po.OrderDate,
                       po.TotalAmount, po.Status, po.EmailSubject, po.EmailBody,
                       po.original_total_value, po.confirmed_total_value, po.etd_date,
                       po.total_cbm, po.total_weight_kg, po.logistics_vehicle,
                       po.logistics_strategy, po.utilization_percentage
                FROM purchase_orders po
                ORDER BY po.PO_ID DESC
            ''')
            columns = [col[0] for col in cursor.description]
            orders = []
            for row in cursor.fetchall():
                o = dict(zip(columns, row))
                # Resolve all items from RequestIDs
                req_ids_str = o.get('RequestIDs') or str(o['RequestID'] or '')
                req_ids = [int(x.strip()) for x in req_ids_str.split(',') if x.strip()]
                items = []
                for rid in req_ids:
                    cursor.execute('SELECT SKU, ProductName, AiRecommendedQty, UserOverriddenQty, TotalValue FROM purchase_requests WHERE RequestID = ?', (rid,))
                    cols2 = [c[0] for c in cursor.description]
                    pr_row = cursor.fetchone()
                    if pr_row:
                        pr = dict(zip(cols2, pr_row))
                        qty = pr.get('UserOverriddenQty') or pr.get('AiRecommendedQty') or 0
                        total_val = float(pr['TotalValue']) if pr['TotalValue'] is not None else 0
                        unit_price = total_val / qty if qty and qty > 0 else 0
                        items.append({
                            'request_id': rid,
                            'sku': pr['SKU'],
                            'product': pr['ProductName'],
                            'quantity': qty,
                            'unit_price': unit_price,
                            'total_value': total_val,
                        })
                # Get po_line_items
                cursor.execute('SELECT * FROM po_line_items WHERE po_id = ?', (o['PO_ID'],))
                li_cols = [c[0] for c in cursor.description]
                line_items = [dict(zip(li_cols, r)) for r in cursor.fetchall()]

                total_amount = float(o['TotalAmount']) if o['TotalAmount'] is not None else 0
                # Fetch supplier email from suppliers table
                supplier_email = ''
                supplier_name = o['SupplierName'] or ''
                if supplier_name:
                    cursor.execute('SELECT email FROM suppliers WHERE name = ?', (supplier_name,))
                    se_row = cursor.fetchone()
                    if se_row:
                        supplier_email = se_row[0] or ''

                orders.append({
                    'po_number': f'PO-{o["PO_ID"]:04d}',
                    'po_id': o['PO_ID'],
                    'request_id': o['RequestID'],
                    'supplier': o['SupplierName'],
                    'supplier_email': supplier_email,
                    'total_value': total_amount,
                    'status': o['Status'],
                    'created_date': str(o['OrderDate']) if o['OrderDate'] else None,
                    'item_count': len(items),
                    'items': items,
                    'line_items': line_items,
                    'original_total_value': float(o.get('original_total_value') or total_amount),
                    'confirmed_total_value': float(o.get('confirmed_total_value') or total_amount),
                    'etd_date': str(o['etd_date']) if o.get('etd_date') else None,
                    'total_cbm': float(o.get('total_cbm') or 0),
                    'total_weight_kg': float(o.get('total_weight_kg') or 0),
                    'logistics_vehicle': o.get('logistics_vehicle') or '',
                    'container_strategy': o.get('logistics_strategy') or '',
                    'utilization_percentage': float(o.get('utilization_percentage') or 0),
                    'email_subject': o.get('EmailSubject'),
                    'email_body': o.get('EmailBody'),
                })
            return {"orders": orders}

    def get_purchase_order_detail(self, po_id_or_number):
        """Get single PO detail by PO_ID (int) or po_number (str like 'PO-0001')"""
        if isinstance(po_id_or_number, str):
            try:
                po_id = int(po_id_or_number.replace('PO-', ''))
            except (ValueError, AttributeError):
                po_id = po_id_or_number
        else:
            po_id = po_id_or_number
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM purchase_orders WHERE PO_ID = ?', (po_id,))
            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                return {"po_number": str(po_id_or_number), "error": "Not found"}
            o = dict(zip(columns, row))
            # Resolve all items from RequestIDs
            req_ids_str = o.get('RequestIDs') or str(o['RequestID'] or '')
            req_ids = [int(x.strip()) for x in req_ids_str.split(',') if x.strip()]
            items = []
            for rid in req_ids:
                cursor.execute('SELECT SKU, ProductName, AiRecommendedQty, UserOverriddenQty, TotalValue FROM purchase_requests WHERE RequestID = ?', (rid,))
                cols2 = [c[0] for c in cursor.description]
                pr_row = cursor.fetchone()
                if pr_row:
                    pr = dict(zip(cols2, pr_row))
                    qty = pr.get('UserOverriddenQty') or pr.get('AiRecommendedQty') or 0
                    total_val = float(pr['TotalValue']) if pr['TotalValue'] is not None else 0
                    unit_price = total_val / qty if qty and qty > 0 else 0
                    items.append({
                        'product': pr['ProductName'],
                        'sku': pr['SKU'],
                        'quantity': qty,
                        'unit_price': unit_price,
                        'total_value': total_val,
                    })
            # Get po_line_items
            cursor.execute('SELECT * FROM po_line_items WHERE po_id = ?', (o['PO_ID'],))
            li_cols = [c[0] for c in cursor.description]
            line_items = [dict(zip(li_cols, r)) for r in cursor.fetchall()]
            # Get revision history
            cursor.execute('SELECT * FROM po_revision_history WHERE po_id = ? ORDER BY timestamp DESC', (o['PO_ID'],))
            rev_cols = [c[0] for c in cursor.description]
            revisions = [dict(zip(rev_cols, r)) for r in cursor.fetchall()]

            total_amount = float(o['TotalAmount']) if o['TotalAmount'] is not None else 0
            return {
                'po_number': f'PO-{o["PO_ID"]:04d}',
                'po_id': o['PO_ID'],
                'supplier': o['SupplierName'],
                'total_value': total_amount,
                'status': o['Status'],
                'created_date': str(o['OrderDate']) if o['OrderDate'] else None,
                'item_count': len(items),
                'items': items,
                'line_items': line_items,
                'original_total_value': float(o.get('original_total_value') or total_amount),
                'confirmed_total_value': float(o.get('confirmed_total_value') or total_amount),
                'etd_date': str(o['etd_date']) if o.get('etd_date') else None,
                'total_cbm': float(o.get('total_cbm') or 0),
                'total_weight_kg': float(o.get('total_weight_kg') or 0),
                'logistics_vehicle': o.get('logistics_vehicle') or '',
                'logistics_strategy': o.get('logistics_strategy') or '',
                'utilization_percentage': float(o.get('utilization_percentage') or 0),
                'revisions': revisions,
                'email_subject': o.get('EmailSubject'),
                'email_body': o.get('EmailBody'),
            }

    def send_purchase_order_email(self, *args, **kwargs):
        return {"success": True}

    def get_email_template(self, po_number, template_type='Standard'):
        """Get pre-filled email template for a PO"""
        detail = self.get_purchase_order_detail(po_number)
        return {
            'subject': detail.get('email_subject', f'Purchase Order {po_number}'),
            'body': detail.get('email_body', f'Dear Supplier,\n\nPlease find attached Purchase Order {po_number}.\n\nBest regards,\nProcurement Team'),
            'supplier': detail.get('supplier', ''),
        }

    # ========================================
    # PO AMENDMENT / NEGOTIATION METHODS
    # ========================================

    def amend_purchase_order(self, po_id: int, line_items: list, etd_date: str = None,
                             reason: str = None, changed_by: str = "Procurement Officer") -> Dict[str, Any]:
        """Apply supplier counter-offer amendments to a PO."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM purchase_orders WHERE PO_ID = ?', (po_id,))
            columns = [col[0] for col in cursor.description]
            po_row = cursor.fetchone()
            if not po_row:
                return {"success": False, "error": "PO not found"}
            po = dict(zip(columns, po_row))
            original_total = float(po.get('original_total_value') or po['TotalAmount'] or 0)

            for amendment in line_items:
                rid = amendment['request_id']
                confirmed_qty = amendment['confirmed_qty']
                confirmed_price = amendment['confirmed_price']

                cursor.execute('SELECT * FROM po_line_items WHERE po_id = ? AND request_id = ?', (po_id, rid))
                li_cols = [c[0] for c in cursor.description]
                existing_row = cursor.fetchone()
                if existing_row:
                    existing = dict(zip(li_cols, existing_row))
                    prev_qty = existing.get('confirmed_qty') or existing['requested_qty']
                    prev_price = float(existing.get('confirmed_price') or existing['requested_price'] or 0)

                    cursor.execute('''
                        UPDATE po_line_items SET confirmed_qty = ?, confirmed_price = ?
                        WHERE po_id = ? AND request_id = ?
                    ''', (confirmed_qty, confirmed_price, po_id, rid))

                    if confirmed_qty != prev_qty:
                        cursor.execute('''
                            INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                            VALUES (?, ?, ?, ?, ?, ?)
                        ''', (po_id, changed_by, f'confirmed_qty (Request {rid})',
                              str(prev_qty), str(confirmed_qty), reason))
                    if confirmed_price != prev_price:
                        cursor.execute('''
                            INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                            VALUES (?, ?, ?, ?, ?, ?)
                        ''', (po_id, changed_by, f'confirmed_price (Request {rid})',
                              f'{prev_price:.2f}', f'{confirmed_price:.2f}', reason))

            if etd_date:
                prev_etd = str(po.get('etd_date') or 'Not set')
                cursor.execute('UPDATE purchase_orders SET etd_date = ? WHERE PO_ID = ?', (etd_date, po_id))
                cursor.execute('''
                    INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (po_id, changed_by, 'etd_date', prev_etd, etd_date, reason))

            cursor.execute('SELECT SUM(confirmed_qty * confirmed_price) FROM po_line_items WHERE po_id = ?', (po_id,))
            new_total_row = cursor.fetchone()
            confirmed_total = float(new_total_row[0]) if new_total_row and new_total_row[0] else 0

            price_increase_pct = ((confirmed_total - original_total) / original_total * 100) if original_total > 0 else 0
            requires_reapproval = price_increase_pct > 5.0
            new_status = 'PENDING_REAPPROVAL' if requires_reapproval else 'NEGOTIATING'

            cursor.execute('''
                UPDATE purchase_orders SET confirmed_total_value = ?, TotalAmount = ?, Status = ? WHERE PO_ID = ?
            ''', (confirmed_total, confirmed_total, new_status, po_id))

            cursor.execute('''
                INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (po_id, changed_by, 'status', po['Status'], new_status,
                  f'Price variance: {price_increase_pct:.1f}%' if requires_reapproval else reason))

            conn.commit()
            return {
                "success": True,
                "po_id": po_id,
                "original_total_value": original_total,
                "confirmed_total_value": confirmed_total,
                "price_variance_pct": round(price_increase_pct, 2),
                "requires_reapproval": requires_reapproval,
                "new_status": new_status,
            }

    def confirm_purchase_order(self, po_id: int, changed_by: str = "Procurement Officer") -> Dict[str, Any]:
        """Lock and confirm PO."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT Status FROM purchase_orders WHERE PO_ID = ?', (po_id,))
            row = cursor.fetchone()
            if not row:
                return {"success": False, "error": "PO not found"}
            current_status = row[0]
            if current_status == 'PENDING_REAPPROVAL':
                return {"success": False, "error": "PO requires executive re-approval before confirmation"}

            cursor.execute('UPDATE purchase_orders SET Status = ? WHERE PO_ID = ?', ('CONFIRMED', po_id))
            cursor.execute('''
                INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (po_id, changed_by, 'status', current_status, 'CONFIRMED', 'PO locked and confirmed'))
            conn.commit()
            return {"success": True, "po_id": po_id, "status": "CONFIRMED"}

    def approve_po_reapproval(self, po_id: int, approver: str = "Executive Approver") -> Dict[str, Any]:
        """Executive approves a PO that exceeded the 5% price variance threshold."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT Status FROM purchase_orders WHERE PO_ID = ?', (po_id,))
            row = cursor.fetchone()
            if not row:
                return {"success": False, "error": "PO not found"}
            if row[0] != 'PENDING_REAPPROVAL':
                return {"success": False, "error": "PO is not pending re-approval"}

            cursor.execute('UPDATE purchase_orders SET Status = ? WHERE PO_ID = ?', ('NEGOTIATING', po_id))
            cursor.execute('''
                INSERT INTO po_revision_history (po_id, changed_by, field_name, previous_value, new_value, reason)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (po_id, approver, 'status', 'PENDING_REAPPROVAL', 'NEGOTIATING',
                  'Executive approved price variance'))
            conn.commit()
            return {"success": True, "po_id": po_id, "status": "NEGOTIATING"}

    def get_po_revision_history(self, po_id: int) -> List[Dict[str, Any]]:
        """Get full revision history for a PO."""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM po_revision_history WHERE po_id = ? ORDER BY timestamp DESC', (po_id,))
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]

    # ========================================
    # NEW WORKFLOW METHODS
    # ========================================

    def save_forecast_as_purchase_requests(self, workflow_result: Dict[str, Any]) -> Dict[str, Any]:
        """Save AI workflow results as new purchase_requests with Status='Draft'"""
        items = self.get_items_from_database()
        logger.info(f"save_forecast_as_purchase_requests: got {len(items)} items from DB")
        inserted_ids = []

        if not items:
            logger.warning("save_forecast_as_purchase_requests: No items found, returning 0")
            return {"success": True, "inserted_count": 0, "request_ids": []}

        # Get seasonal multipliers for the plan period
        now = datetime.now()
        plan_start = now.strftime('%Y-%m-%d')
        plan_end = (now + timedelta(days=90)).strftime('%Y-%m-%d')
        try:
            seasonality = self.get_seasonality_analysis(plan_start, plan_end)
            sku_multipliers = seasonality.get('sku_multipliers', {})
            detected_events = seasonality.get('detected_events', [])
        except Exception:
            sku_multipliers = {}
            detected_events = []

        with self.get_connection() as conn:
            cursor = conn.cursor()

            # Clear existing Draft PRs before inserting new ones
            cursor.execute("DELETE FROM purchase_requests WHERE Status = 'Draft'")
            logger.info("Cleared existing Draft purchase requests")

            for item in items:
                try:
                    sales_30 = item.get('sales_last_30_days') or 0
                    sales_60 = item.get('sales_last_60_days') or 0
                    current_stock = item.get('current_stock') or 0
                    lead_time = item.get('lead_time_days') or 14
                    unit_price = float(item.get('unit_price') or 0)
                    moq = item.get('moq') or 1
                    supplier_name = item.get('supplier') or 'N/A'

                    daily_sales = sales_30 / 30 if sales_30 > 0 else 0
                    days_coverage = current_stock / daily_sales if daily_sales > 0 else 999

                    if days_coverage < lead_time:
                        risk = 'Critical'
                    elif days_coverage < lead_time * 2:
                        risk = 'Warning'
                    else:
                        risk = 'Low'

                    base_qty = int(sales_30 * 3 * 1.2)
                    seasonal_mult = sku_multipliers.get(item['sku'], 1.0)
                    recommended_qty = max(int(base_qty * seasonal_mult), moq)
                    total_val = recommended_qty * unit_price

                    seasonal_note = ""
                    if seasonal_mult > 1.0:
                        event_names = ", ".join(e['event'] for e in detected_events if e.get('multiplier', 1.0) > 1.0)
                        seasonal_note = f" Seasonal adjustment: x{seasonal_mult} ({event_names})."
                    insight = f"AI forecast: 3-month demand. Coverage: {days_coverage:.0f} days vs {lead_time}-day lead time.{seasonal_note}"

                    # Calculate logistics using real specs from run.md
                    from logistics_constants import calculate_full_logistics
                    units_per_ctn = item.get('units_per_ctn') or 1
                    cbm_per_ctn = float(item.get('cbm_per_ctn') or 0.05)
                    weight_per_ctn = float(item.get('weight_per_ctn') or 0)
                    num_cartons = math.ceil(recommended_qty / units_per_ctn) if units_per_ctn > 0 else recommended_qty
                    total_cbm = round(num_cartons * cbm_per_ctn, 2)
                    total_weight = round(num_cartons * weight_per_ctn, 2)

                    logistics = calculate_full_logistics(total_cbm, total_weight)
                    container_strategy = logistics["strategy"]
                    container_fill_rate = int(logistics["container_utilization_pct"])
                    container_size = logistics["container_size"]
                    container_count = logistics["container_count"]
                    recommended_lorry = logistics["recommended_lorry"]
                    lorry_count = logistics["lorry_count"]
                    fill_suggestion = logistics["fill_up_suggestion"]
                    weight_util_pct = int(logistics["weight_utilization_pct"])
                    spare_cbm = logistics["spare_cbm"]
                    estimated_transit = lead_time + (14 if container_strategy != 'Local Bulk' else 0)

                    ai_reasoning = (
                        f"Demand-based: {recommended_qty} units ({num_cartons} cartons) for 3-month coverage. "
                        f"Ship via {container_count}x {container_size} ({container_fill_rate}% vol / {weight_util_pct}% wt). "
                        f"Local delivery: {lorry_count}x {recommended_lorry}. "
                        f"Coverage: {days_coverage:.0f} days.{seasonal_note}"
                    )

                    cursor.execute('''
                        INSERT INTO purchase_requests
                        (SKU, ProductName, AiRecommendedQty, RiskLevel, AiInsightText,
                         TotalValue, Last30DaysSales, Last60DaysSales, CurrentStock,
                         SupplierLeadTime, StockCoverageDays, SupplierName, MinOrderQty, Status,
                         TotalCBM, ContainerStrategy, ContainerFillRate, EstimatedTransitDays,
                         AiReasoning, TotalWeightKg, LogisticsVehicle,
                         ContainerSize, ContainerCount, RecommendedLorry, LorryCount,
                         FillUpSuggestion, WeightUtilizationPct, SpareCbm)
                        OUTPUT INSERTED.RequestID
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Draft',
                                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        item['sku'], item.get('product') or '', recommended_qty, risk, insight,
                        total_val, sales_30, sales_60,
                        current_stock, lead_time, int(days_coverage),
                        supplier_name, moq,
                        total_cbm, container_strategy, container_fill_rate, estimated_transit,
                        ai_reasoning, total_weight, container_size,
                        container_size, container_count, recommended_lorry, lorry_count,
                        fill_suggestion, weight_util_pct, spare_cbm
                    ))
                    row = cursor.fetchone()
                    new_id = row[0] if row else None
                    if new_id is not None:
                        inserted_ids.append(int(new_id))
                except Exception as e:
                    logger.error(f"Error inserting PR for SKU {item.get('sku')}: {e}")
                    continue

        logger.info(f"save_forecast_as_purchase_requests: inserted {len(inserted_ids)} PRs")
        return {"success": True, "inserted_count": len(inserted_ids), "request_ids": inserted_ids}

    def submit_for_approval(self, request_ids: List[int]) -> Dict[str, Any]:
        """Update Status from 'Draft' to 'Pending' and create approval_status entries"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join(['?'] * len(request_ids))
            # Update purchase_requests status (keep in sync)
            cursor.execute(f'''
                UPDATE purchase_requests
                SET Status = 'Pending', LastModified = GETDATE()
                WHERE RequestID IN ({placeholders}) AND Status = 'Draft'
            ''', request_ids)
            updated = cursor.rowcount
            # Insert into approval_status for each PR (skip if already exists for this request)
            for rid in request_ids:
                cursor.execute('''
                    IF NOT EXISTS (SELECT 1 FROM approval_status WHERE RequestID = ? AND Status IN ('Pending', 'Approved', 'Rejected'))
                    INSERT INTO approval_status (RequestID, Status, SubmittedDate, LastModified)
                    VALUES (?, 'Pending', GETDATE(), GETDATE())
                ''', (rid, rid))
            conn.commit()
            return {"success": True, "updated_count": updated}

    def get_purchase_requests_by_status(self, statuses: List[str]) -> Dict[str, Any]:
        """Get PRs filtered by multiple status values, enriched with approval_status data"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join(['?'] * len(statuses))
            cursor.execute(f'''
                SELECT pr.*,
                       ap.ApprovalID,
                       ap.SubmittedDate,
                       ap.ActionDate       AS ApprovalActionDate,
                       ap.ApproverID       AS ApprovalApproverID,
                       ap.RejectionReason  AS ApprovalRejectionReason,
                       ap.Notes            AS ApprovalNotes
                FROM purchase_requests pr
                LEFT JOIN approval_status ap
                    ON ap.RequestID = pr.RequestID
                    AND ap.ApprovalID = (
                        SELECT MAX(ApprovalID) FROM approval_status WHERE RequestID = pr.RequestID
                    )
                WHERE pr.Status IN ({placeholders})
                ORDER BY CASE UPPER(pr.RiskLevel)
                    WHEN 'CRITICAL' THEN 0 WHEN 'WARNING' THEN 1 ELSE 2
                END, pr.TotalValue DESC
            ''', statuses)
            columns = [col[0] for col in cursor.description]
            rows = []
            for row in cursor.fetchall():
                item = dict(zip(columns, row))
                if 'TotalValue' in item and item['TotalValue'] is not None:
                    item['TotalValue'] = float(item['TotalValue'])
                # Surface approval_status fields onto the record for frontend compatibility
                if item.get('SubmittedDate'):
                    item['SubmittedDate'] = str(item['SubmittedDate'])
                if item.get('ApprovalActionDate'):
                    item['ActionDate'] = str(item['ApprovalActionDate'])
                rows.append(self._ensure_container_logistics(item))
            return {"requests": rows, "total_count": len(rows)}

    def approve_purchase_requests(self, request_ids: List[int], approver_id: int) -> Dict[str, Any]:
        """Approve selected purchase requests — updates both purchase_requests and approval_status"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join(['?'] * len(request_ids))
            # Keep purchase_requests.Status in sync
            cursor.execute(f'''
                UPDATE purchase_requests
                SET Status = 'Approved', ApprovalDate = GETDATE(), ApproverID = ?, LastModified = GETDATE()
                WHERE RequestID IN ({placeholders}) AND Status = 'Pending'
            ''', [approver_id] + request_ids)
            approved = cursor.rowcount
            # Update the dedicated approval_status table
            for rid in request_ids:
                cursor.execute('''
                    UPDATE approval_status
                    SET Status = 'Approved', ApproverID = ?, ActionDate = GETDATE(), LastModified = GETDATE()
                    WHERE RequestID = ? AND Status = 'Pending'
                ''', (approver_id, rid))
            conn.commit()
            return {"success": True, "approved_count": approved}

    def reject_purchase_requests(self, request_ids: List[int], approver_id: int, reason: str) -> Dict[str, Any]:
        """Reject selected purchase requests — updates both purchase_requests and approval_status"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join(['?'] * len(request_ids))
            # Keep purchase_requests.Status in sync
            cursor.execute(f'''
                UPDATE purchase_requests
                SET Status = 'Rejected', RejectionReason = ?, ApprovalDate = GETDATE(),
                    ApproverID = ?, LastModified = GETDATE()
                WHERE RequestID IN ({placeholders}) AND Status = 'Pending'
            ''', [reason, approver_id] + request_ids)
            rejected = cursor.rowcount
            # Update the dedicated approval_status table
            for rid in request_ids:
                cursor.execute('''
                    UPDATE approval_status
                    SET Status = 'Rejected', ApproverID = ?, ActionDate = GETDATE(),
                        RejectionReason = ?, LastModified = GETDATE()
                    WHERE RequestID = ? AND Status = 'Pending'
                ''', (approver_id, reason, rid))
            conn.commit()
            return {"success": True, "rejected_count": rejected}

    def generate_purchase_order(self, request_id: int) -> Dict[str, Any]:
        """Generate a PO from an approved purchase request"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM purchase_requests WHERE RequestID = ? AND Status = ?', (request_id, 'Approved'))
            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                return {"success": False, "error": "Request not found or not approved"}
            pr = dict(zip(columns, row))
            qty = pr.get('UserOverriddenQty') or pr['AiRecommendedQty']
            total_val = float(pr['TotalValue']) if pr['TotalValue'] is not None else 0
            email_subject = f"Purchase Order - {pr['ProductName']} ({pr['SKU']})"
            email_body = (
                f"Dear {pr['SupplierName']},\n\n"
                f"Please find below our Purchase Order:\n\n"
                f"Product: {pr['ProductName']}\n"
                f"SKU: {pr['SKU']}\n"
                f"Quantity: {qty} units\n"
                f"Total Amount: RM {total_val:,.2f}\n\n"
                f"Please confirm receipt and expected delivery date.\n\n"
                f"Best regards,\nProcurement Team"
            )
            cursor.execute('''
                INSERT INTO purchase_orders (RequestID, SupplierName, TotalAmount, Status, EmailSubject, EmailBody)
                VALUES (?, ?, ?, 'DRAFT', ?, ?)
            ''', (request_id, pr['SupplierName'], total_val, email_subject, email_body))
            cursor.execute('SELECT SCOPE_IDENTITY()')
            po_id = int(cursor.fetchone()[0])
            conn.commit()
            return {"success": True, "po_id": po_id, "po_number": f"PO-{po_id:04d}"}

    def generate_grouped_purchase_orders(self, request_ids: List[int]) -> Dict[str, Any]:
        """Generate POs from multiple approved requests, grouped by supplier (one PO per supplier)"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join('?' * len(request_ids))
            cursor.execute(
                f'SELECT * FROM purchase_requests WHERE RequestID IN ({placeholders}) AND Status = ?',
                (*request_ids, 'Approved')
            )
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            if not rows:
                return {"success": False, "error": "No approved requests found"}

            # Group by supplier
            from collections import defaultdict
            grouped = defaultdict(list)
            for pr in rows:
                grouped[pr['SupplierName']].append(pr)

            created_pos = []
            for supplier, items in grouped.items():
                total_amount = sum(float(item['TotalValue']) for item in items if item.get('TotalValue'))
                all_request_ids = ','.join(str(item['RequestID']) for item in items)

                # Use pre-computed logistics already stored on each PR row
                agg_cbm = sum(float(item.get('TotalCBM') or 0) for item in items)
                agg_weight = sum(float(item.get('TotalWeightKg') or 0) for item in items)

                # Fallback if no logistics data on PRs
                if agg_cbm == 0 and agg_weight == 0:
                    from logistics_constants import calculate_logistics
                    logistics_items = []
                    for item in items:
                        qty = int(item.get('UserOverriddenQty') or item.get('AiRecommendedQty') or 0)
                        logistics_items.append({
                            'forecasted_qty': qty,
                            'units_per_ctn': 10,
                            'cbm_per_ctn': 0.05,
                            'weight_per_ctn': 10.0,
                        })
                    _fallback = calculate_logistics(logistics_items)
                    agg_cbm = _fallback['total_cbm']
                    agg_weight = _fallback['total_weight_kg']

                from logistics_constants import select_vehicle
                vehicle, strategy, util_pct = select_vehicle(agg_cbm, agg_weight)
                po_logistics = {
                    'total_cbm': round(agg_cbm, 2),
                    'total_weight_kg': round(agg_weight, 2),
                    'recommended_vehicle': vehicle,
                    'strategy': strategy,
                    'utilization_percentage': round(util_pct, 1),
                }

                # Build email with all items
                items_lines = ""
                for item in items:
                    qty = item.get('UserOverriddenQty') or item.get('AiRecommendedQty') or 1
                    val = float(item['TotalValue']) if item.get('TotalValue') else 0
                    items_lines += f"  - {item['ProductName']} ({item['SKU']}): {qty} units @ RM {val:,.2f}\n"

                email_subject = f"Purchase Order - {supplier} ({len(items)} item(s))"
                email_body = (
                    f"Dear {supplier},\n\n"
                    f"Please find below our Purchase Order:\n\n"
                    f"{items_lines}\n"
                    f"Total Amount: RM {total_amount:,.2f}\n"
                    f"Total CBM: {po_logistics['total_cbm']} m\u00b3 | Weight: {po_logistics['total_weight_kg']} kg\n"
                    f"Transport: {po_logistics['recommended_vehicle']} ({po_logistics['strategy']})\n\n"
                    f"Please confirm receipt and expected delivery date.\n\n"
                    f"Best regards,\nProcurement Team"
                )
                # Use OUTPUT INSERTED.PO_ID to reliably get the new row ID (SCOPE_IDENTITY can return None)
                cursor.execute('''
                    INSERT INTO purchase_orders (RequestID, RequestIDs, SupplierName, TotalAmount, Status, EmailSubject, EmailBody,
                                                 original_total_value, confirmed_total_value,
                                                 total_cbm, total_weight_kg, logistics_vehicle, logistics_strategy, utilization_percentage)
                    OUTPUT INSERTED.PO_ID
                    VALUES (?, ?, ?, ?, 'DRAFT', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (items[0]['RequestID'], all_request_ids, supplier, total_amount, email_subject, email_body,
                      total_amount, total_amount,
                      po_logistics['total_cbm'], po_logistics['total_weight_kg'],
                      po_logistics['recommended_vehicle'], po_logistics['strategy'],
                      po_logistics['utilization_percentage']))
                row = cursor.fetchone()
                po_id = int(row[0]) if row and row[0] is not None else None
                if po_id is None:
                    # Final fallback: query MAX(PO_ID)
                    cursor.execute('SELECT MAX(PO_ID) FROM purchase_orders')
                    po_id = int(cursor.fetchone()[0] or 0)

                # Insert line items for each PR in this grouped PO
                for item in items:
                    qty_raw = item.get('UserOverriddenQty') or item.get('AiRecommendedQty')
                    item_qty = int(qty_raw) if qty_raw is not None else 1
                    item_total = float(item['TotalValue']) if item.get('TotalValue') else 0
                    item_unit_price = item_total / item_qty if item_qty > 0 else 0
                    cursor.execute('''
                        INSERT INTO po_line_items (po_id, request_id, sku, product_name,
                                                   requested_qty, requested_price, confirmed_qty, confirmed_price)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (po_id, item['RequestID'], item['SKU'], item['ProductName'],
                          item_qty, item_unit_price, item_qty, item_unit_price))

                created_pos.append({
                    "po_id": po_id,
                    "po_number": f"PO-{po_id:04d}",
                    "supplier": supplier,
                    "item_count": len(items),
                    "total_value": total_amount,
                })

            # Update PR status to PO_Generated so they leave the approval screen
            all_ids = ','.join('?' * len(request_ids))
            cursor.execute(
                f"UPDATE purchase_requests SET Status = 'PO_Generated' WHERE RequestID IN ({all_ids}) AND Status = 'Approved'",
                request_ids
            )

            conn.commit()
            return {"success": True, "pos_created": len(created_pos), "purchase_orders": created_pos}

    def get_users(self) -> List[Dict[str, Any]]:
        """Get all users"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM users')
            columns = [col[0] for col in cursor.description]
            rows = []
            for row in cursor.fetchall():
                item = dict(zip(columns, row))
                if 'ApprovalLimit' in item and item['ApprovalLimit'] is not None:
                    item['ApprovalLimit'] = float(item['ApprovalLimit'])
                rows.append(item)
            return rows

    # ========================================
    # REMAINING STUBS
    # ========================================

    def get_analytics_data(self):
        """Get real analytics data from purchase_orders, purchase_requests, and items"""
        with self.get_connection() as conn:
            cursor = conn.cursor()

            # Total spend from purchase orders
            cursor.execute("SELECT COALESCE(SUM(TotalAmount), 0) FROM purchase_orders")
            total_spend = float(cursor.fetchone()[0])

            # Approved count
            cursor.execute("SELECT COUNT(*) FROM purchase_requests WHERE Status = 'Approved'")
            approved_count = cursor.fetchone()[0]

            # Average approval time
            cursor.execute("""
                SELECT AVG(DATEDIFF(HOUR, CreatedDate, ApprovalDate) / 24.0)
                FROM purchase_requests
                WHERE Status = 'Approved' AND ApprovalDate IS NOT NULL AND CreatedDate IS NOT NULL
            """)
            avg_days_row = cursor.fetchone()[0]
            avg_approval_time = f"{float(avg_days_row):.1f} days" if avg_days_row else "N/A"

            # Cost savings
            cursor.execute("""
                SELECT COALESCE(SUM(
                    ABS((AiRecommendedQty * (TotalValue / NULLIF(AiRecommendedQty, 0)))
                    - (UserOverriddenQty * (TotalValue / NULLIF(AiRecommendedQty, 0))))
                ), 0)
                FROM purchase_requests
                WHERE UserOverriddenQty IS NOT NULL AND UserOverriddenQty < AiRecommendedQty
            """)
            cost_savings = float(cursor.fetchone()[0])

            # Spending by category
            cursor.execute("""
                SELECT i.category, COALESCE(SUM(pr.TotalValue), 0) as amount
                FROM purchase_requests pr
                LEFT JOIN items i ON pr.SKU = i.sku
                WHERE pr.Status IN ('Approved', 'Pending', 'Draft')
                GROUP BY i.category
                ORDER BY amount DESC
            """)
            columns = [col[0] for col in cursor.description]
            category_rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            total_category_spend = sum(float(r['amount']) for r in category_rows) if category_rows else 1
            spending_by_category = []
            for r in category_rows:
                cat_name = r['category'] or 'Uncategorized'
                amount = float(r['amount'])
                pct = (amount / total_category_spend * 100) if total_category_spend > 0 else 0
                spending_by_category.append({
                    'category': cat_name,
                    'amount': amount,
                    'percentage': round(pct, 1),
                })

            if not spending_by_category:
                spending_by_category = [
                    {'category': 'Machinery', 'amount': 115000, 'percentage': 45},
                    {'category': 'Electronics', 'amount': 56000, 'percentage': 22},
                    {'category': 'Safety Equipment', 'amount': 41000, 'percentage': 16},
                    {'category': 'Supplies', 'amount': 28000, 'percentage': 11},
                    {'category': 'Office Supplies', 'amount': 15000, 'percentage': 6},
                ]
                total_spend = total_spend or 255000
                approved_count = approved_count or 12
                cost_savings = cost_savings or 18500

            return {
                'total_spend': f'RM {total_spend:,.2f}',
                'approved_batches': approved_count,
                'avg_approval_time': avg_approval_time,
                'cost_savings': f'RM {cost_savings:,.2f}',
                'spending_by_category': spending_by_category,
            }

    def get_approval_history(self):
        """Get approval history from approval_status JOIN purchase_requests JOIN users"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT pr.RequestID, pr.SKU, pr.ProductName, pr.TotalValue,
                       ap.Status, ap.ActionDate AS ApprovalDate, ap.RejectionReason,
                       ap.ApproverID, pr.RiskLevel, pr.SupplierName,
                       ap.SubmittedDate,
                       u.Name as ApproverName
                FROM approval_status ap
                JOIN purchase_requests pr ON ap.RequestID = pr.RequestID
                LEFT JOIN users u ON ap.ApproverID = u.UserID
                WHERE ap.Status IN ('Approved', 'Rejected')
                ORDER BY ap.ActionDate DESC
            """)
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]

            history = []
            for row in rows:
                approval_date = str(row.get('ApprovalDate', '')) if row.get('ApprovalDate') else ''
                date_part = approval_date.split(' ')[0] if approval_date else 'N/A'
                time_part = approval_date.split(' ')[1].split('.')[0] if approval_date and ' ' in approval_date else ''
                total_val = float(row['TotalValue']) if row.get('TotalValue') else 0

                history.append({
                    'batch_id': f"PR-{row['RequestID']:04d}",
                    'officer': row.get('ApproverName') or f"User #{row.get('ApproverID', 'N/A')}",
                    'action': row['Status'].upper(),
                    'date': date_part,
                    'time': time_part,
                    'total_value': total_val,
                    'item_count': 1,
                    'notes': row.get('RejectionReason', '') or '',
                    'product': row.get('ProductName', ''),
                    'sku': row.get('SKU', ''),
                    'risk_level': row.get('RiskLevel', ''),
                    'supplier': row.get('SupplierName', ''),
                    'submitted_date': str(row.get('SubmittedDate', '')) if row.get('SubmittedDate') else '',
                })

            return {"history": history}

    def get_role_mapping_data(self):
        """Get role mapping data from procurement_users table"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM procurement_users ORDER BY UserID')
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]

            officers = []
            for row in rows:
                suppliers = row.get('AssignedSuppliers', '') or ''
                supplier_list = [s.strip() for s in suppliers.split(',') if s.strip()]
                entry = {
                    'id': str(row['UserID']),
                    'name': row['UserName'],
                    'role': row['Role'],
                    'email': f"{row['UserName'].lower().replace(' ', '.')}@chinhin.com",
                    'approval_limit': float(row['ApprovalLimit']) if row.get('ApprovalLimit') else 0,
                    'categories': supplier_list,
                    'reports_to': str(row['ReportsTo']) if row.get('ReportsTo') else None,
                }
                officers.append(entry)

            # Compute subordinates for supervisors
            for entry in officers:
                subs = [o['id'] for o in officers if o.get('reports_to') == entry['id']]
                if subs:
                    entry['subordinates'] = subs

            if not officers:
                officers = [
                    {'id': '1', 'name': 'John Lance', 'role': 'Senior Procurement Officer',
                     'email': 'john.lance@chinhin.com', 'approval_limit': 5000.00,
                     'categories': ['TechCorp Industries', 'ChemSupply Co'], 'reports_to': '2'},
                    {'id': '2', 'name': 'Sarah Lee', 'role': 'General Manager',
                     'email': 'sarah.lee@chinhin.com', 'approval_limit': 0,
                     'categories': [], 'subordinates': ['1', '4']},
                    {'id': '3', 'name': 'David Tan', 'role': 'Managing Director',
                     'email': 'david.tan@chinhin.com', 'approval_limit': 0,
                     'categories': []},
                    {'id': '4', 'name': 'Emily Wong', 'role': 'Procurement Executive',
                     'email': 'emily.wong@chinhin.com', 'approval_limit': 10000.00,
                     'categories': ['HydroMax Ltd', 'SafetyFirst Inc', 'MotorTech Systems'], 'reports_to': '2'},
                ]

            # Load routing rules from DB
            cursor.execute('SELECT * FROM routing_rules ORDER BY id')
            rule_columns = [col[0] for col in cursor.description]
            rule_rows = [dict(zip(rule_columns, row)) for row in cursor.fetchall()]
            routing_rules = []
            for r in rule_rows:
                routing_rules.append({
                    'id': str(r['id']),
                    'condition': r['condition_text'],
                    'assign_to': r['assign_to'],
                    'is_active': bool(r.get('is_active', 1)),
                })

            return {'officers': officers, 'routing_rules': routing_rules}

    def get_agent_status(self):
        return {}

    def get_test_agent_response(self):
        return {}

    def get_guardian_result(self, *args):
        return {}

    def get_forecaster_result(self, *args):
        return {}

    def get_logistics_result(self, *args):
        return {}

    def get_forecast_result(self, *args):
        return {}

    def get_uploaded_items(self):
        return []

    def update_role_assignment(self, officer_id, category=None, action=None, approval_limit=None, **kwargs):
        """Update officer's assigned suppliers or approval limit"""
        with self.get_connection() as conn:
            cursor = conn.cursor()

            if approval_limit is not None:
                cursor.execute(
                    'UPDATE procurement_users SET ApprovalLimit = ? WHERE UserID = ?',
                    (float(approval_limit), int(officer_id))
                )
                conn.commit()
                return {"success": True, "message": "Approval limit updated"}

            if category and action:
                cursor.execute(
                    'SELECT AssignedSuppliers FROM procurement_users WHERE UserID = ?',
                    (int(officer_id),)
                )
                row = cursor.fetchone()
                if not row:
                    return {"success": False, "message": "Officer not found"}

                current = row[0] or ''
                items = [s.strip() for s in current.split(',') if s.strip()]

                if action == 'add' and category not in items:
                    items.append(category)
                elif action == 'remove' and category in items:
                    items.remove(category)

                new_value = ','.join(items)
                cursor.execute(
                    'UPDATE procurement_users SET AssignedSuppliers = ? WHERE UserID = ?',
                    (new_value, int(officer_id))
                )
                conn.commit()
                return {"success": True, "message": f"Category {action}ed"}

            return {"success": True}

    def assign_supervisor(self, officer_id, supervisor_id):
        """Assign an officer to a supervisor (GM/MD)"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT Role FROM procurement_users WHERE UserID = ?', (int(officer_id),))
            row = cursor.fetchone()
            if not row:
                return {"success": False, "message": "Officer not found"}
            if row[0] in ('General Manager', 'Managing Director'):
                return {"success": False, "message": "Cannot reassign a supervisor role"}
            if supervisor_id:
                cursor.execute('SELECT Role FROM procurement_users WHERE UserID = ?', (int(supervisor_id),))
                sup_row = cursor.fetchone()
                if not sup_row or sup_row[0] not in ('General Manager', 'Managing Director'):
                    return {"success": False, "message": "Invalid supervisor"}
            cursor.execute(
                'UPDATE procurement_users SET ReportsTo = ? WHERE UserID = ?',
                (int(supervisor_id) if supervisor_id else None, int(officer_id))
            )
            conn.commit()
            return {"success": True, "message": "Supervisor assignment updated"}

    def add_routing_rule(self, rule_data):
        """Add a new routing rule to DB"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO routing_rules (condition_text, assign_to, is_active)
                VALUES (?, ?, 1)
            ''', (rule_data.get('condition', ''), rule_data.get('assign_to', '')))
            conn.commit()
            cursor.execute('SELECT @@IDENTITY')
            new_id = cursor.fetchone()[0]
            return {"success": True, "rule_id": str(new_id)}

    def update_routing_rule(self, rule_id, rule_data):
        """Update an existing routing rule"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE routing_rules
                SET condition_text = ?, assign_to = ?, is_active = ?
                WHERE id = ?
            ''', (
                rule_data.get('condition', ''),
                rule_data.get('assign_to', ''),
                1 if rule_data.get('is_active', True) else 0,
                int(rule_id),
            ))
            conn.commit()
            return {"success": True}

    def delete_routing_rule(self, rule_id):
        """Delete a routing rule"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM routing_rules WHERE id = ?', (int(rule_id),))
            conn.commit()
            return {"success": True}

    def get_ai_workflow_result(self, batch_data: Dict[str, Any]) -> Dict[str, Any]:
        """Run AI workflow — delegates to run_ai_procurement_workflow"""
        config = batch_data.get('config', {})
        return self.run_ai_procurement_workflow(config)


# ========================================
# USAGE EXAMPLE
# ========================================

def main():
    """
    Example: Complete AI procurement workflow
    Database → Verify → AI Agents → Parse → Save
    """
    print("\n" + "="*80)
    print("AZURE SQL SERVICE - AI PROCUREMENT WORKFLOW")
    print("="*80 + "\n")
    
    # Initialize service
    service = AzureSQLService()
    
    # Configure workflow
    config = {
        "forecast_period_months": 3,
        "safety_buffer": 1.2,
        "festival_mode": False,
        "risk_threshold": 3.0
    }
    
    # Run complete 5-step workflow
    result = service.run_ai_procurement_workflow(config)
    
    if result['success']:
        print("\n✅ WORKFLOW COMPLETED SUCCESSFULLY!")
        print(f"Batch ID: {result['batch_id']}")
        print(f"Items Processed: {result['items_processed']}")
        print(f"\nSummary:")
        print(json.dumps(result['summary'], indent=2))
        
        # Get batch details
        batch = service.get_batch_detail(result['batch_id'])
        print(f"\nSaved {len(batch['items'])} items to database")
        
    else:
        print(f"\n❌ WORKFLOW FAILED")
        print(f"Error: {result.get('error')}")


if __name__ == "__main__":
    main()