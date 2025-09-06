# 🕵️‍♂️ OSINT Forge

A lightweight, privacy-respecting OSINT runner + Streamlit dashboard.  
Run username scans, collect results, and review everything in a clean, modern UI.  

⚠️ **Ethics & legality**: Only use on targets you are authorized to research.  
You are responsible for compliance with all applicable laws.

---

## ✨ Features

- 🔍 **One-command scans**: Search with popular OSINT tools (e.g., Sherlock).  
- 📑 **Normalized output**: All results collected into a single `summary.json`.  
- 📊 **Modern dashboard**: Streamlit UI with results shown in real time.  
- ⚙️ **Configurable storage**:  
  - Overwrite mode (single folder)  
  - Keep last *N* runs  
  - Compact mode (prune intermediates)  
- 🌐 **Works offline**: No cloud lock-in, everything runs locally.  
- 📦 **Small repo**: Bulky data files ignored by default via `.gitignore`.

---

## 📦 Installation

Clone the repository and set up:

```bash
git clone https://github.com/IRISHDEVELOPERDEV/osint-forge.git
cd osint-forge
chmod +x setup.sh run.sh osint-master.sh
./setup.sh

