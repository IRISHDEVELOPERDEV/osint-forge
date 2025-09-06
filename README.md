# OSINT Forge

A lightweight, privacy-respecting OSINT runner + Streamlit dashboard that lets you:
- Run username scans with popular tools (e.g., Sherlock).
- Collect/normalize results into a single `summary.json`.
- Review results in a clean dashboard, with options to save or overwrite runs.
- Keep your repo small by ignoring bulky artifacts (results are local by default).

> ⚠️ **Ethics & legality:** Use only on targets you are authorized to research. You are responsible for compliance with all applicable laws.

---

## Features

- **One-command scans** from the UI (Streamlit) or CLI.
- **Normalized output** (`summary.json`) for easy parsing and sharing.
- **Configurable storage**: single-folder overwrite, keep last N runs, compact mode (prune intermediates).
- **Works offline** after tools are installed (no cloud lock-in).
- **Small repo**: results are `.gitignore`’d by default.

---

## What’s inside

