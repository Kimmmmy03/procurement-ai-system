#!/bin/bash
# ============================================
# Procurement System - Run Backend & Frontend
# ============================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Procurement AI System - Launcher${NC}"
echo -e "${BLUE}========================================${NC}"

# --- Backend ---
echo -e "\n${GREEN}[1/2] Starting Backend (FastAPI)...${NC}"
cd "$PROJECT_DIR/backend"

if [ ! -d "venv" ]; then
    echo -e "${BLUE}Creating virtual environment...${NC}"
    python -m venv venv
fi

source venv/Scripts/activate 2>/dev/null || source venv/bin/activate 2>/dev/null

pip install -r requirements.txt --quiet 2>/dev/null

echo -e "${GREEN}Backend running at http://localhost:8000${NC}"
echo -e "${GREEN}API docs at http://localhost:8000/api/docs${NC}"
python main.py &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 3

# --- Frontend ---
echo -e "\n${GREEN}[2/2] Starting Frontend (Flutter)...${NC}"
cd "$PROJECT_DIR/frontend"

flutter pub get --quiet 2>/dev/null
echo -e "${GREEN}Launching Flutter on Chrome...${NC}"
flutter run -d chrome &
FRONTEND_PID=$!

# --- Cleanup on exit ---
cleanup() {
    echo -e "\n${RED}Shutting down...${NC}"
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Both services are running!${NC}"
echo -e "${BLUE}Backend:  http://localhost:8000/api/docs${NC}"
echo -e "${BLUE}Frontend: http://localhost:3000 (Chrome)${NC}"
echo -e "${BLUE}Press Ctrl+C to stop both.${NC}"
echo -e "${BLUE}========================================${NC}"

wait
