#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_ENV="${VENV_ENV:-$HOME/venvs/faster-whisper/env.sh}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-7860}"

if [ ! -f "$VENV_ENV" ]; then
  echo "Missing environment file: $VENV_ENV"
  echo "Run: bash scripts/setup_wsl_faster_whisper.sh"
  exit 1
fi

cd "$PROJECT_DIR"
source "$VENV_ENV"
python scripts/app.py --host "$HOST" --port "$PORT"
