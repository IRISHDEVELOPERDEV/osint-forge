# 🕵️ OSINT Forge

**OSINT Forge** is a lightweight, privacy-respecting OSINT runner + Streamlit dashboard that lets you:  

- Run username scans with popular tools (e.g., Sherlock, Holehe).  
- Collect and normalize results into a single `summary.json`.  
- Review results in a clean, modern dashboard, with options to save or overwrite runs.  
- Keep your repo small by ignoring bulky artifacts (results are local by default).  

⚠️ **Ethics & legality:** Use only on targets you are authorized to research. You are responsible for compliance with all applicable laws.

---

## ✨ Features

- **One-command scans** from the UI (Streamlit) or CLI.  
- **Normalized output** → all results stored in `summary.json` for easy parsing/sharing.  
- **Configurable storage** → overwrite in a single folder, keep last N runs, or compact mode to prune intermediates.  
- **Works offline** → no cloud lock-in after tools are installed.  
- **Small repo** → bulky outputs are `.gitignore`’d by default.  

---

## 🔗 Pipeline & Tools

Currently integrated:
- **Sherlock** → username enumeration across social media.  
- **Holehe** → check if an email is registered on popular sites.  
- **Custom parsers** → normalize tool outputs into `summary.json`.  

Planned integrations:
- **theHarvester** (emails/domains)  
- **ExifTool** (image metadata)  
- **PhoneInfoga** (phone number intelligence)  

> Tools are modular — if something isn’t installed, the pipeline skips gracefully.  

---

## 📦 Installation

Clone the repository and install requirements:  

```bash
git clone https://github.com/YOUR_USERNAME/osint-forge.git
cd osint-forge

# install python dependencies
pip install -r requirements.txt

# make shell script executable
chmod +x osint-master.sh
