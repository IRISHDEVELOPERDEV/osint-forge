#!/usr/bin/env bash
# Launch the Streamlit dashboard with the repo's venv if present.

set -euo pipefail
cd "$(dirname "$0")"

if [ -d ".venv" ]; then
  # shellcheck disable=SC1091
  source ".venv/bin/activate"
fi

export PYTHONUNBUFFERED=1
exec python3 -m streamlit run osint_dash.py --server.headless=true
