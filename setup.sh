#!/usr/bin/env bash
set -e

echo "== OSINT Forge setup =="

# --- Detect apt-based system (Ubuntu/Debian/ChromeOS Linux) ---
if command -v apt >/dev/null 2>&1; then
  echo "[*] Installing system packages..."
  sudo apt update
  sudo apt install -y python3 python3-venv python3-pip git jq exiftool ffmpeg
else
  echo "[-] Non-apt system detected. Please install equivalents of: python3, python3-venv, git, jq, exiftool, ffmpeg"
  echo "    Then rerun this script."
  exit 1
fi

# --- Create/refresh virtualenv ---
echo "[*] Creating virtualenv .venv ..."
python3 -m venv .venv
# shellcheck disable=SC1091
. .venv/bin/activate
python -m pip install --upgrade pip

# --- Python deps ---
echo "[*] Installing Python requirements..."
pip install -r requirements.txt

# --- Clone Sherlock once (Maigret comes from pip) ---
if [ ! -d "sherlock" ]; then
  echo "[*] Cloning Sherlock..."
  git clone https://github.com/sherlock-project/sherlock.git
else
  echo "[*] Updating Sherlock..."
  (cd sherlock && git pull --ff-only || true)
fi

# --- Make scripts executable ---
chmod +x osint-master.sh run.sh || true

echo ""
echo "[✔] Setup complete."
echo "    • Run dashboard:   ./run.sh"
echo "    • Or CLI only:     .venv/bin/bash osint-master.sh <username> [--keep]"
