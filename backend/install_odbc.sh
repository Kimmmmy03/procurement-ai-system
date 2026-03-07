#!/bin/bash
echo "=== Installing ODBC Driver 18 for SQL Server ==="
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg 2>/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list
apt-get update -qq
ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get install -y -qq msodbcsql18 unixodbc-dev
echo "=== ODBC Driver installed ==="
