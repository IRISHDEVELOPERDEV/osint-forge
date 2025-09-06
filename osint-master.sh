#!/usr/bin/env bash
#
# OSINT Forge – pipeline runner
# Usage:  ./osint-master.sh <username>
#
# ENV toggles (all optional):
#   RESULTS_BASE   (default: "$HOME/osint_results")
#   FAST           (0/1)  default: 0
#   DEEP           (0/1)  default: 1
#   DEEP_X         (0/1)  default: 0   # attempt X/Twitter checks where possible
#   TOP_OPEN       (int)  default: 0   # open top-N links in $BROWSER
#   COMPACT        (0/1)  default: 1   # prune heavy intermediates
#   SINGLE_FOLDER  (0/1)  default: 1   # overwrite one folder per target
#
# Tools used if present on PATH (best-effort; script still succeeds if missing):
#   sherlock, maigret, holehe, snscrape (for X), curl
set -euo pipefail

# ---------- helpers ----------
now_utc_iso() { date -u +"%Y%m%d_%H%M%S"; }
log()        { printf "%s %s\n" "[$(date -u +"%H:%M:%S")]" "$*"; }
have()       { command -v "$1" >/dev/null 2>&1; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ---------- args ----------
TARGET="${1:-}"
[ -z "$TARGET" ] && die "No username supplied. Usage: ./osint-master.sh <username>"

# ---------- env defaults ----------
RESULTS_BASE="${RESULTS_BASE:-$HOME/osint_results}"
FAST="${FAST:-0}"
DEEP="${DEEP:-1}"
DEEP_X="${DEEP_X:-0}"
TOP_OPEN="${TOP_OPEN:-0}"
COMPACT="${COMPACT:-1}"
SINGLE_FOLDER="${SINGLE_FOLDER:-1}"

# ---------- folders ----------
ts="$(now_utc_iso)"
target_root="$RESULTS_BASE/$TARGET"

if [ "$SINGLE_FOLDER" = "1" ]; then
  run_folder="$target_root"              # overwrite into one folder
  rm -rf "$run_folder" 2>/dev/null || true
else
  run_folder="$target_root/$ts"          # keep per-run history
fi

data_dir="$run_folder/data"
mkdir -p "$data_dir"

log "== Pipeline for: $TARGET =="
log "[env] FAST=$FAST DEEP=$DEEP DEEP_X=$DEEP_X TOP_OPEN=$TOP_OPEN COMPACT=$COMPACT SINGLE_FOLDER=$SINGLE_FOLDER"
log "[dirs] RUN=$run_folder"

summary_json="$data_dir/summary.json"
tmp_dir="$data_dir/_tmp"
mkdir -p "$tmp_dir"

# initialize summary
cat >"$summary_json" <<JSON
{
  "target": "$(printf "%s" "$TARGET")",
  "timestamp": "$(now_utc_iso)",
  "run_folder": "$(printf "%s" "$run_folder" | sed 's/\\/\\\\/g')",
  "mainstream": [],
  "emails": [],
  "phones": [],
  "avatars": []
}
JSON

# jq helper (fallback to python if jq missing)
json_add_array_items() {
  local key="$1"; shift
  if have jq; then
    jq --argjson arr "$(printf '%s\n' "$@" | awk 'NF' | jq -R . | jq -s .)" \
       --arg key "$key" '.[$key] += $arr' "$summary_json" >"$summary_json.tmp" && mv "$summary_json.tmp" "$summary_json"
  else
    # poor-man append using python stdlib
    python3 - <<'PY' "$summary_json" "$key" "$@"
import json,sys
p=sys.argv
fn=p[1]; key=p[2]; items=p[3:]
d=json.load(open(fn))
d.setdefault(key,[]).extend(items)
json.dump(d,open(fn,"w"),indent=2)
PY
  fi
}

collect_urls_from_file() {
  # print unique URLs
  grep -Eo '(https?://[^ ]+)' "$1" 2>/dev/null | sed 's/[",]$//' | sort -u
}

# ---------- Sherlock ----------
if have sherlock; then
  log "[*] Running Sherlock…"
  # Use --print-found for concise output; redirect all to file for parsing.
  sherlock "$TARGET" --print-found > "$tmp_dir/sherlock.txt" 2>/dev/null || true
  urls=$(collect_urls_from_file "$tmp_dir/sherlock.txt" || true)
  if [ -n "$urls" ]; then
    json_add_array_items "mainstream" $urls
  fi
else
  log "[!] sherlock not installed; skipping."
fi

# ---------- Maigret (optional deep) ----------
if [ "$DEEP" = "1" ] && have maigret; then
  log "[*] Running Maigret… (this can take a while)"
  # Compact stdout list
  maigret "$TARGET" --pdf --folder "$tmp_dir" > "$tmp_dir/maigret.txt" 2>/dev/null || true
  urls=$(collect_urls_from_file "$tmp_dir/maigret.txt" || true)
  if [ -n "$urls" ]; then
    json_add_array_items "mainstream" $urls
  fi
else
  [ "$DEEP" = "1" ] || log "[i] Deep disabled; skipping Maigret."
  have maigret || log "[!] maigret not installed; skipping."
fi

# ---------- holehe (emails from providers, best-effort) ----------
if have holehe; then
  # holehe is email-centric; try a few likely emails based on target
  log "[*] Running holehe (guesses)…"
  candidate_emails=$(printf "%s\n" \
    "$TARGET@gmail.com" "$TARGET@yahoo.com" "$TARGET@outlook.com" \
    | sort -u)
  found_emails=()
  while read -r em; do
    [ -z "$em" ] && continue
    holehe "$em" > "$tmp_dir/holehe-$em.txt" 2>/dev/null || true
    # naive check: if any provider says "Found", keep it
    if grep -qi "found" "$tmp_dir/holehe-$em.txt" 2>/dev/null; then
      found_emails+=("$em")
    fi
  done <<< "$candidate_emails"
  if [ ${#found_emails[@]} -gt 0 ]; then
    json_add_array_items "emails" "${found_emails[@]}"
  fi
else
  log "[!] holehe not installed; skipping."
fi

# ---------- X/Twitter (via snscrape if enabled) ----------
if [ "$DEEP_X" = "1" ] && have snscrape; then
  log "[*] Checking X/Twitter via snscrape…"
  # Try profile URL and a few recent posts just for presence
  snscrape --nofollow --jsonl twitter-user "$TARGET" > "$tmp_dir/x_user.jsonl" 2>/dev/null || true
  if [ -s "$tmp_dir/x_user.jsonl" ]; then
    profile_url="https://twitter.com/$TARGET"
    json_add_array_items "mainstream" "$profile_url"
  fi
else
  [ "$DEEP_X" = "1" ] || log "[i] X/Twitter disabled."
  have snscrape || log "[!] snscrape not installed; skipping X."
fi

# ---------- Simple phone scrape from found pages (very conservative) ----------
# Best-effort: fetch a few URLs and look for phone-like patterns.
phones_found=()
if have curl; then
  log "[*] Light phone scan on first few URLs…"
  if have jq; then
    mapfile -t first_urls < <(jq -r '.mainstream[]?' "$summary_json" | head -n 10)
  else
    # fallback parse
    mapfile -t first_urls < <(grep -Eo '"mainstream":[^]]*\]' "$summary_json" | grep -Eo 'https?://[^"]+' | head -n 10)
  fi
  for u in "${first_urls[@]}"; do
    html="$(curl -m 6 -fsSL "$u" 2>/dev/null || true)"
    [ -z "$html" ] && continue
    # very conservative phone regex
    while read -r ph; do
      [ -z "$ph" ] && continue
      phones_found+=("$ph")
    done < <(printf "%s" "$html" | grep -Eo '(\+?[0-9][0-9\-\.\s\(\)]{6,}[0-9])' | sed 's/  */ /g' | sort -u | head -n 5)
  done
fi
if [ ${#phones_found[@]} -gt 0 ]; then
  json_add_array_items "phones" "${phones_found[@]}"
fi

# ---------- Compact/prune ----------
if [ "$COMPACT" = "1" ]; then
  log "[*] Compact mode: pruning intermediates."
  rm -rf "$tmp_dir" 2>/dev/null || true
fi

# ---------- Done ----------
log "[ok] Wrote summary.json to $summary_json"

# optionally open a few links
if [ "$TOP_OPEN" -gt 0 ]; then
  if have jq; then
    mapfile -t open_urls < <(jq -r '.mainstream[]?' "$summary_json" | head -n "$TOP_OPEN")
  else
    mapfile -t open_urls < <(grep -Eo 'https?://[^"]+' "$summary_json" | head -n "$TOP_OPEN")
  fi
  if [ ${#open_urls[@]} -gt 0 ]; then
    log "[i] Opening top ${#open_urls[@]} links…"
    for u in "${open_urls[@]}"; do
      (xdg-open "$u" >/dev/null 2>&1 || open "$u" >/dev/null 2>&1 || true) &
    done
  fi
fi

exit 0
