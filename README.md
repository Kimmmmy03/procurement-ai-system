<p align="center">
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/FastAPI-0.115+-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Flutter-3.27-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Azure_AI_Foundry-Multi--Agent-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white" alt="Azure AI" />
  <img src="https://img.shields.io/badge/Azure_SQL-Production-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white" alt="Azure SQL" />
</p>

<h1 align="center">Procurement AI System</h1>

<p align="center">
  <strong>AI-powered procurement planning and management system</strong><br/>
  Built for <strong>Chin Hin Group</strong> &mdash; transforming raw purchase order data into actionable procurement plans using three specialised Microsoft Azure AI Foundry Agents.
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#database-setup">Database Setup</a> &bull;
  <a href="#ai-agent-pipeline">AI Pipeline</a> &bull;
  <a href="#api-reference">API Reference</a> &bull;
  <a href="#deployment">Deployment</a>
</p>

---

## Features

### Dual-Portal Design

The system serves two user roles with dedicated interfaces:

| Procurement Officer | Executive Approver (GM/MD) |
|---|---|
| Dashboard with critical alerts & risk overview | Dashboard with pending batches & approval metrics |
| 3-tab data import (PO PDF, Xeersoft, Supplier & Item Master) | Batch review with decision cockpit |
| AI forecast with 16-event seasonality detection | PO re-approval for >5% price variance |
| PR management with override & audit trail | Spend analytics & KPI tracking |
| PO generation, PDF export, email templates | Expandable approval history with full audit trail |
| Warehouse stock dashboard with charts & inline editing | Role mapping & supervisor hierarchy management |
| Custom seasonality event management | Custom seasonality calendar with side-by-side view |

### Core Capabilities

**Data Intelligence**
- **3-Agent AI Pipeline** &mdash; Guardian (quality), Forecaster (demand), Logistics (shipping) via Microsoft Azure AI Foundry
- **Hybrid ML Forecasting** &mdash; sklearn regression + seasonal decomposition provides mathematical baseline; AI agents add qualitative adjustments
- **16-Event Malaysian Calendar** &mdash; CNY, Raya, Deepavali, Christmas, Thaipusam, Monsoon, and 10 more seasonal events with per-event demand multipliers
- **Custom Seasonality Events** &mdash; Add company-specific peaks that override or supplement the AI calendar
- **Multi-Channel Inventory** &mdash; 15 warehouse/channel segments: Main Warehouse, TikTok, Shopee, Lazada, e-Store, B2B Projects, Corporate, East Mas, Minor BP, Rework, BP, DM, SIRIM, Incomplete, MGIT

**Procurement Workflow**
- **Purchase Request Management** &mdash; Review AI recommendations, override quantities with categorised reasons, batch submit for approval
- **Batch Approval Workflow** &mdash; Decision cockpit metrics, approve/reject with mandatory notes, full audit trail
- **PO Generation** &mdash; Auto-grouped by supplier, CBM/weight logistics calculations, vehicle selection (10 vehicles), PDF export with selectable text, email templates
- **OA Negotiation** &mdash; Supplier counter-offer handling, price/qty amendments, 5% variance auto-escalation to executive re-approval
- **PO Completion** &mdash; Mark confirmed POs as completed to close the procurement cycle

**Data Import**
- **Purchase Orders** &mdash; PDF upload with intelligent table extraction (pdfplumber + PyPDF2 fallback)
- **Xeersoft Inventory** &mdash; Excel upload with 15-channel stock + 24-month sales history, inline annotation extraction
- **Supplier & Item Master** &mdash; Flexible column mapping, auto-deduplication, vendor master upsert, automatic items table rebuild

**Warehouse Stock Dashboard**
- Pie chart for stock distribution by channel
- Bar charts per item with all 15 channels
- Clickable SKU for quick search filtering
- Inline stock editing per channel with save to database

**PO Lifecycle**
```
DRAFT --> SENT --> NEGOTIATING --> CONFIRMED --> COMPLETED
                       |
                       +--> PENDING_REAPPROVAL (if price increase > 5%)
```

**UI/UX**
- Glassmorphism design system with frosted-glass containers
- Dark gradient theme (0xFF0F2027 to 0xFF2C5364)
- Skeleton shimmer loading on all data-fetching screens
- Responsive two-column layouts for dashboards
- Click-to-expand detail views throughout
- FL Chart pie charts and bar charts for data visualisation

---

## Architecture

```
+-----------------------------------------------------------+
|                    Flutter Frontend                         |
|   Procurement Officer UI   |   Executive Approver UI       |
+-------------+----------------------------+-----------------+
              | HTTPS / REST API           |
+-------------v----------------------------v-----------------+
|               FastAPI Backend (Python)                      |
|  12 APIRouter modules | 50+ endpoints | Pydantic models    |
|       |             |                                       |
|  +----v-------------v----------------------------------+    |
|  |            Database Factory                         |    |
|  |  SQLite (Dev) <-------> Azure SQL (Production)      |    |
|  +-----------------------------------------------------+    |
+-----------------------+-------------------------------------+
                        |
+-----------------------v-------------------------------------+
|          Microsoft Azure AI Foundry                         |
|  Guardian Agent --> Forecaster Agent --> Logistics Agent     |
+-------------------------------------------------------------+
```

### Tech Stack

| Layer | Technologies |
|---|---|
| **Frontend** | Flutter 3.27, Dart 3.x, Provider, Dio, FL Chart, pdf/printing, file_picker |
| **Backend** | FastAPI, Python 3.10+, Pydantic, Uvicorn, pandas, openpyxl, pdfplumber, PyPDF2 |
| **AI** | Microsoft Azure AI Foundry (3-agent streaming workflow) |
| **Database** | SQLite (dev) / Azure SQL (prod) with factory pattern |
| **Infrastructure** | Azure App Service, Azure Static Web Apps, GitHub Actions CI/CD |

---

## Quick Start

### Prerequisites

- Python 3.10+
- Flutter 3.27+ & Dart 3.x
- Git

### 1. Clone & Setup Backend

```bash
git clone https://github.com/Kimmmmy03/procurement-ai-system.git
cd procurement-ai-system/backend

# Create virtual environment
# Windows (use py launcher if `python` is not in PATH)
py -m venv venv
# macOS/Linux
python3 -m venv venv

# Activate (Windows)
venv\Scripts\activate
# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your Azure credentials (or leave USE_AZURE_SQL=false for SQLite)

# Start server
python main.py
```

Backend available at `http://localhost:8000` | Swagger docs at `http://localhost:8000/api/docs`

### 2. Setup Frontend

```bash
cd ../frontend

flutter pub get
flutter run -d chrome          # Web
# OR
flutter run -d windows         # Desktop
```

### 3. First Run Workflow

1. **Upload Data** &mdash; Go to Data Import, upload Xeersoft inventory file, then Supplier & Item Master
2. **Run Forecast** &mdash; Configure date range, review seasonality events, run 3-agent AI workflow
3. **Manage PRs** &mdash; Review auto-generated Draft purchase requests, override if needed
4. **Submit & Approve** &mdash; Submit batch, switch to Executive role, approve/reject
5. **Generate POs** &mdash; Generate purchase orders grouped by supplier, export PDF, send emails
6. **Warehouse Stock** &mdash; View stock distribution across 15 channels, edit values inline

---

## Database Setup

The system supports two database modes controlled by `USE_AZURE_SQL` in `backend/.env`.

### Option A: SQLite (Development — zero setup)

```env
USE_AZURE_SQL=false
```

The database file (`procurement.db`) is auto-created on first startup. No installation required. Use this for local development and testing.

---

### Option B: Azure SQL (Production)

#### Step 1 — Install ODBC Driver 17

The backend requires **Microsoft ODBC Driver 17 for SQL Server**.

**Windows:**

Download and install from Microsoft:
[https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

Verify installation:
```bash
python -c "import pyodbc; print([d for d in pyodbc.drivers() if 'SQL Server' in d])"
# Expected: ['ODBC Driver 17 for SQL Server']
```

**macOS:**
```bash
brew tap microsoft/mssql-release https://github.com/microsoft/homebrew-mssql-release
brew install msodbcsql17
```

**Ubuntu/Debian:**
```bash
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql17
```

---

#### Step 2 — Configure Azure SQL Firewall

Azure SQL blocks all external connections by default. You must whitelist your IP.

1. Go to **Azure Portal** → navigate to your SQL Server (not the database)
2. Left menu → **Networking** (or **Firewalls and virtual networks**)
3. Click **+ Add client IP** — Azure auto-detects your current public IP
4. Click **Save** and wait ~2 minutes for the rule to propagate

To find your current public IP:
```bash
curl -s https://api.ipify.org
```

> **Note:** If your IP changes (home networks, VPNs), you must add the new IP each time. For a stable setup, use an Azure Virtual Network or configure an IP range.

---

#### Step 3 — Configure `.env`

```env
# Switch to Azure SQL
USE_AZURE_SQL=true

# Azure SQL credentials
AZURE_SQL_SERVER=your-server-name.database.windows.net
AZURE_SQL_DATABASE=your-database-name
AZURE_SQL_USERNAME=your-sql-username
AZURE_SQL_PASSWORD=your-password
AZURE_SQL_DRIVER=ODBC Driver 17 for SQL Server
```

---

#### Step 4 — Verify Connection

Test the connection before starting the backend:

```bash
cd backend
venv\Scripts\activate   # Windows
python -c "
import pyodbc, os
from dotenv import load_dotenv
load_dotenv()

conn_str = (
    f\"Driver={{{os.getenv('AZURE_SQL_DRIVER')}}};\"
    f\"Server={os.getenv('AZURE_SQL_SERVER')};\"
    f\"Database={os.getenv('AZURE_SQL_DATABASE')};\"
    f\"Uid={os.getenv('AZURE_SQL_USERNAME')};\"
    f\"Pwd={os.getenv('AZURE_SQL_PASSWORD')};\"
    'Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;'
)
conn = pyodbc.connect(conn_str)
print('Azure SQL connected successfully')
conn.close()
"
```

---

#### Step 5 — Initialise Schema

On first startup with `USE_AZURE_SQL=true`, the backend automatically creates all 14 tables via `database_factory.py`. Simply start the server:

```bash
python main.py
```

Look for this in the logs to confirm Azure SQL is active:
```
✅ Database connected successfully: Azure SQL
   📦 X items loaded from database
```

If you see `[WARN] Falling back to SQLite...`, check the troubleshooting section below.

---

#### Azure SQL Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Client with IP address '...' is not allowed` | IP not whitelisted | Add your IP in Azure Portal → SQL Server → Networking |
| `cannot import name 'ResponseStreamEventType'` | Wrong azure-ai-projects version | Run `pip install -r requirements.txt` to get correct version |
| `Data source name not found` | ODBC driver missing or wrong version | Install ODBC Driver 17 and set `AZURE_SQL_DRIVER=ODBC Driver 17 for SQL Server` in `.env` |
| `Login failed for user` | Wrong credentials | Double-check `AZURE_SQL_USERNAME` and `AZURE_SQL_PASSWORD` in `.env` |
| Still falls back to SQLite | Exception swallowed silently | Run the Step 4 connection test script to see the real error |

---

## AI Agent Pipeline

Three chained Azure AI Foundry Agents process procurement data sequentially:

```
                    +--------------------------+
                    |     Guardian Agent        |
                    |  Data quality validation  |
                    |  Failure rate flagging     |
                    +------------+-------------+
                                 |
                    +------------v-------------+
                    |    Forecaster Agent       |
                    |  Historical analysis      |
                    |  Seasonality adjustment   |
                    |  3-month demand forecast  |
                    |  MOQ rounding & buffers   |
                    +------------+-------------+
                                 |
                    +------------v-------------+
                    |     Logistics Agent       |
                    |  Container optimisation   |
                    |  FCL / LCL / Local Bulk   |
                    |  Supplier grouping        |
                    |  Transit time planning    |
                    +--------------------------+
```

**Input:** SKU, product, category, stock levels, 30/60/90-day sales, unit price, supplier, lead time, MOQ, failure rate, packaging dimensions

**Fallback:** If Azure AI is unavailable, the system calculates recommendations using historical sales data, seasonal multipliers, and stock coverage algorithms.

---

## API Reference

**50+ endpoints** across 12 router modules. Full interactive docs at `/api/docs` (Swagger UI).

| Module | Endpoints | Key Operations |
|---|---|---|
| **Dashboard** | 2 | Officer & approver metrics, alerts, recent activity |
| **Upload** | 4 | Purchase order PDFs, Xeersoft inventory, supplier master, templates |
| **Forecast** | 6 | 3-agent AI workflow, individual agents, seasonality analysis |
| **Purchase Requests** | 7 | List, detail, override, submit, save forecast |
| **Approval** | 10 | Batches, approve/reject, history, pending requests |
| **Orders** | 11 | Generate, email, amend, confirm, complete, re-approve, revisions |
| **Analytics** | 3 | Spend trends, KPIs, cost savings |
| **Role Mapping** | 3 | Assignments, supervisor hierarchy |
| **Warehouse** | 2 | Stock listing with channel totals, inline stock updates |
| **Custom Seasonality** | 3 | CRUD for company-specific seasonal events |
| **Health** | 2 | System status, DB & AI agent connectivity |
| **Database Admin** | 3 | Item list, table statistics, data management |

---

## Database

**14 tables** with dual-database support:

| Table | Purpose |
|---|---|
| `items` | Product master (derived from inventory_segments + vendor_master) |
| `purchase_requests` | AI recommendations & approval workflow |
| `purchase_orders` | PO lifecycle with logistics data |
| `po_line_items` | Requested vs confirmed qty/price per item |
| `po_revision_history` | Full PO amendment audit trail |
| `inventory_segments` | Multi-channel stock (15 channels per item) |
| `monthly_sales_history` | Per-SKU per-month sales for seasonality |
| `forecast_batches` | AI workflow batch tracking |
| `suppliers` | Supplier master with contact & terms |
| `vendor_master` | Raw supplier specs from upload (18 columns) |
| `users` | System users & approver roles |
| `procurement_users` | Role mapping with supervisor hierarchy |
| `custom_seasonality_events` | Company-specific seasonal demand events |
| `shipping_documents` | Attached docs per PO |

**Development:** `USE_AZURE_SQL=false` — SQLite auto-created, no setup needed
**Production:** `USE_AZURE_SQL=true` — Azure SQL with ODBC Driver 17 for SQL Server

---

## Environment Configuration

Copy `backend/.env.example` to `backend/.env` and configure:

```env
# Database Mode (false = SQLite for development)
USE_AZURE_SQL=false

# Azure SQL (required when USE_AZURE_SQL=true)
AZURE_SQL_SERVER=your-server.database.windows.net
AZURE_SQL_DATABASE=procurement-db
AZURE_SQL_USERNAME=your-username
AZURE_SQL_PASSWORD=your-password
AZURE_SQL_DRIVER=ODBC Driver 17 for SQL Server

# Azure AI Foundry
AZURE_AI_ENDPOINT=https://your-resource.services.ai.azure.com/api/projects/your-project
AZURE_AI_WORKFLOW_NAME=intelligent-procurement-flow
USE_AZURE_AI=true
```

---
---

## Project Structure

```
procurement-system/
|-- backend/
|   |-- main.py                    # FastAPI app factory
|   |-- deps.py                    # Dependency injection
|   |-- database_factory.py        # SQLite / Azure SQL switcher
|   |-- database_service.py        # SQLite implementation
|   |-- azure_sql_service.py       # Azure SQL implementation
|   |-- azure_agent_service.py     # Azure AI Foundry integration
|   |-- seasonality_service.py     # 16-event Malaysian calendar
|   |-- ml_forecasting_service.py  # sklearn regression + seasonal
|   |-- xeersoft_ingestion.py      # ERP data cleaning pipeline
|   |-- logistics_constants.py     # Vehicle constraints & calculations
|   |-- models/                    # Pydantic models
|   |-- routers/                   # 12 APIRouter modules
|   |-- requirements.txt
|   |-- .env.example
|
|-- frontend/
|   |-- lib/
|   |   |-- main.dart              # App entry, Provider, Material 3
|   |   |-- services/
|   |   |   |-- api_service.dart   # Dio HTTP client (50+ methods)
|   |   |-- models/
|   |   |   |-- procurement_models.dart
|   |   |-- screens/
|   |   |   |-- role_selection_screen.dart
|   |   |   |-- dashboard_screen.dart
|   |   |   |-- upload_screen.dart
|   |   |   |-- forecast_screen.dart
|   |   |   |-- warehouse_stock_screen.dart
|   |   |   |-- custom_seasonality_screen.dart
|   |   |   |-- purchase_orders_screen.dart
|   |   |   |-- purchase_requests/    # Decomposed PR management
|   |   |   |-- approver/             # Executive portal (7 screens)
|   |   |-- widgets/                  # Glassmorphism UI components
|   |-- pubspec.yaml
|
|-- .github/workflows/
|   |-- main_procurement-ai-backend.yml   # Backend CI/CD
|   |-- deploy-frontend.yml              # Frontend CI/CD
```

---

## Design Patterns

| Pattern | Implementation |
|---|---|
| **Factory** | `database_factory.py` switches SQLite / Azure SQL based on env var |
| **Dependency Injection** | `deps.py` + FastAPI `Depends()` for DB and agent services |
| **Graceful Degradation** | System operates without AI agents using database-backed calculations |
| **Living Document** | POs tracked as versioned documents with full revision history |
| **Threshold Routing** | >5% price variance auto-escalates to executive re-approval |
| **Glassmorphism** | Consistent frosted-glass UI with `BackdropFilter` components |
| **Skeleton Loading** | Animated shimmer placeholders on all data-fetching screens |

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Backend won't start | Check Python 3.10+, activate venv, `pip install -r requirements.txt` |
| `python` not found on Windows | Use `py -m venv venv` instead of `python -m venv venv` |
| Falls back to SQLite | Add your IP to Azure SQL firewall; run the Step 4 connection test to see the real error |
| Wrong ODBC driver | Install ODBC Driver 17 and set `AZURE_SQL_DRIVER=ODBC Driver 17 for SQL Server` in `.env` |
| Backend crashes on Azure | Upgrade from B1 to B3 or P1v3 plan (needs more RAM) |
| AI agents not connecting | System auto-falls back to DB calculations; check `AZURE_AI_ENDPOINT` |
| Frontend can't reach backend | Confirm port 8000, check `baseUrl` in `api_service.dart` |
| Flutter build issues | `flutter clean && flutter pub get`, verify Flutter 3.27+ |
| Dashboard shows zeros | Upload Xeersoft data + Supplier Master, then run forecast |
| CORS errors | Backend allows all origins by default; check `main.py` middleware |
| PDF upload detects 0 items | Check PDF has tabular data; pdfplumber needs structured tables |
| Static Web App not updating | Verify `AZURE_STATIC_WEB_APPS_API_TOKEN` secret in GitHub repo |

---

<p align="center">
  Built with <strong>FastAPI</strong> + <strong>Flutter</strong> + <strong>Microsoft Azure AI Foundry</strong><br/>
  <sub>Chin Hin Group &mdash; Procurement AI System</sub>
</p>
