# OSINT Forge – Streamlit dashboard
# Run:  streamlit run osint_dash.py
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

import streamlit as st

APP_TITLE = "🕵️ OSINT Dashboard"
DEFAULT_RESULTS_BASE = os.path.expanduser("~/osint_results")
PIPELINE = os.path.abspath("./osint-master.sh")

st.set_page_config(page_title="OSINT Dashboard", page_icon="🕵️", layout="wide")


# ---------- utilities ----------
def sh_quote(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"


def list_runs(base: Path, target_filter: str | None = None) -> List[Path]:
    runs: List[Path] = []
    if not base.exists():
        return runs
    for target_dir in sorted(base.iterdir()):
        if not target_dir.is_dir():
            continue
        if target_filter and target_filter.lower() not in target_dir.name.lower():
            continue
        # either single-folder or dated subfolders
        data = target_dir / "data" / "summary.json"
        if data.exists():
            runs.append(target_dir)
        else:
            for sub in sorted(target_dir.iterdir()):
                if (sub / "data" / "summary.json").exists():
                    runs.append(sub)
    return sorted(runs, key=lambda p: p.stat().st_mtime, reverse=True)


def load_summary(run_folder: Path) -> Dict[str, Any] | None:
    sj = run_folder / "data" / "summary.json"
    if not sj.exists():
        return None
    try:
        return json.loads(sj.read_text(encoding="utf-8"))
    except Exception:
        return None


def run_pipeline(
    target: str,
    results_base: Path,
    deep: bool,
    include_x: bool,
    compact: bool,
    single_folder: bool,
    top_open: int,
    fast: bool,
) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env.update(
        {
            "RESULTS_BASE": str(results_base),
            "DEEP": "1" if deep else "0",
            "DEEP_X": "1" if include_x else "0",
            "COMPACT": "1" if compact else "0",
            "SINGLE_FOLDER": "1" if single_folder else "0",
            "TOP_OPEN": str(top_open),
            "FAST": "1" if fast else "0",
        }
    )
    cmd = [PIPELINE, target]
    return subprocess.run(cmd, env=env, capture_output=True, text=True)


def pretty_count_card(label: str, value: int, emoji: str) -> None:
    st.markdown(
        f"""
        <div style="border-radius:14px;background:#101722;border:1px solid #1f2a3a;padding:18px 20px;margin-bottom:10px;">
          <div style="opacity:.85;font-size:13px">{emoji} {label}</div>
          <div style="font-size:40px;font-weight:700;margin-top:2px">{value}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


# ---------- sidebar: run a scan ----------
with st.sidebar:
    st.header("Run a new scan")
    target = st.text_input("Target username or name", value="", placeholder="e.g. extræmily")

    deep = st.checkbox("Deep scan", value=True)
    include_x = st.checkbox("Include X/Twitter", value=False)
    compact = st.checkbox("Compact mode", value=True)

    st.markdown("---")
    st.subheader("Storage")
    single_folder = st.checkbox("Single folder (overwrite)", value=True)
    keep_n = st.number_input("Keep latest N runs", min_value=1, max_value=100, value=5, step=1)
    results_base = Path(st.text_input("Results base folder", value=DEFAULT_RESULTS_BASE))
    results_base.mkdir(parents=True, exist_ok=True)

    st.markdown("---")
    run_btn = st.button("▶ Run scan", use_container_width=True)

# housekeeping: keep N runs per target when not single folder
if not single_folder and results_base.exists():
    # prune older runs per target
    for target_dir in results_base.iterdir():
        if not target_dir.is_dir():
            continue
        runs = list_runs(target_dir.parent, target_dir.name)
        if len(runs) > keep_n:
            for old in runs[keep_n:]:
                shutil.rmtree(old, ignore_errors=True)

# run pipeline if requested
if run_btn:
    if not target.strip():
        st.toast("Enter a target username.", icon="⚠️")
    elif not Path(PIPELINE).exists():
        st.toast("Pipeline script not found. Make sure osint-master.sh is in repo root.", icon="❌")
    else:
        with st.spinner("Running pipeline…"):
            cp = run_pipeline(
                target=target.strip(),
                results_base=results_base,
                deep=deep,
                include_x=include_x,
                compact=compact,
                single_folder=single_folder,
                top_open=0,
                fast=False,
            )
        if cp.returncode != 0:
            st.error("Pipeline failed.")
            st.code(cp.stderr or cp.stdout, language="bash")
        else:
            st.success("Done")
            if cp.stdout.strip():
                with st.expander("Pipeline output"):
                    st.code(cp.stdout.strip(), language="bash")

# ---------- main layout ----------
st.title(APP_TITLE)

# Run picker
runs = list_runs(results_base)
opt_labels = []
for r in runs:
    sj = load_summary(r)
    ts = sj.get("timestamp") if sj else ""
    target_name = sj.get("target") if sj else r.parent.name
    opt_labels.append(f"{target_name} — {ts or r.name}")

sel = st.selectbox("Pick a run", options=opt_labels, index=0 if opt_labels else None)

if not sel:
    st.info("Run a scan from the left, or enter a target then click **Run scan**.")
    st.stop()

idx = opt_labels.index(sel)
run_folder = runs[idx]
summary = load_summary(run_folder) or {}

col1, col2, col3 = st.columns([1.5, 1, 1])
with col1:
    st.caption("Run folder")
    st.code(str(run_folder), language="bash")
with col2:
    st.caption("Summary JSON")
    st.code("summary.json")
with col3:
    st.caption("Timestamp")
    st.code(summary.get("timestamp", "—"))

# KPI cards
mainstream = list(dict.fromkeys(summary.get("mainstream", [])))  # dedupe
emails = list(dict.fromkeys(summary.get("emails", [])))
phones = list(dict.fromkeys(summary.get("phones", [])))
avatars = list(dict.fromkeys(summary.get("avatars", [])))

c1, c2, c3, c4 = st.columns(4)
with c1:
    pretty_count_card("Mainstream URLs", len(mainstream), "🌐")
with c2:
    pretty_count_card("Emails", len(emails), "📧")
with c3:
    pretty_count_card("Phones", len(phones), "📱")
with c4:
    pretty_count_card("Avatars", len(avatars), "🖼️")

# Sections
st.subheader("Links")
if mainstream:
    for u in mainstream:
        st.markdown(f"- [{u}]({u})")
else:
    st.caption("No links found.")

st.subheader("Emails")
if emails:
    st.code("\n".join(emails))
else:
    st.caption("No emails found.")

st.subheader("Phones")
if phones:
    st.code("\n".join(phones))
else:
    st.caption("No phones found.")

with st.expander("Raw summary.json"):
    st.json(summary)
