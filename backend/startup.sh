#!/bin/bash
set -e

echo "=== Procurement AI Backend Startup ==="

# Install ODBC Driver 18 for SQL Server on Linux App Service
if ! odbcinst -q -d -n "ODBC Driver 18 for SQL Server" > /dev/null 2>&1; then
    echo "Installing ODBC Driver 18 for SQL Server..."

    # Detect Debian/Ubuntu version for correct repo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_VERSION="${VERSION_CODENAME}"
        DISTRO_ID="${ID}"
        echo "Detected OS: ${DISTRO_ID} ${DISTRO_VERSION}"
    fi

    apt-get update -qq
    ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gnupg2 curl apt-transport-https 2>/dev/null

    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

    # Try multiple repo configurations (Azure images vary)
    for codename in "$DISTRO_VERSION" "bookworm" "bullseye" "jammy"; do
        if [ -n "$codename" ]; then
            echo "Trying repo for: $codename"
            if [ "$DISTRO_ID" = "ubuntu" ]; then
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/${VERSION_ID}/prod ${codename} main" > /etc/apt/sources.list.d/mssql-release.list
            else
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/${VERSION_ID:-11}/prod ${codename} main" > /etc/apt/sources.list.d/mssql-release.list
            fi
            apt-get update -qq 2>/dev/null
            if ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get install -y -qq msodbcsql18 unixodbc-dev 2>/dev/null; then
                echo "ODBC Driver 18 installed successfully using repo: $codename"
                break
            fi
        fi
    done

    # Verify installation
    if odbcinst -q -d -n "ODBC Driver 18 for SQL Server" > /dev/null 2>&1; then
        echo "ODBC Driver 18 verified."
    else
        echo "WARNING: ODBC Driver 18 installation may have failed. App will try to start anyway."
    fi
else
    echo "ODBC Driver 18 already installed."
fi

echo "Starting gunicorn with 2 workers..."

# Use 2 workers for B2 plan (2 cores, 3.5GB RAM)
# Each worker loads ~500-800MB (FastAPI + pandas + AI agents)
# --timeout 120: allow slow AI agent initialization
# --graceful-timeout 30: allow in-flight requests to finish
gunicorn main:app \
    --workers 2 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --graceful-timeout 30 \
    --access-logfile - \
    --error-logfile -
