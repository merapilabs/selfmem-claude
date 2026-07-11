#!/usr/bin/env bash
# selfmem-recall.sh — Claude Code recall hook (shell)
#
# Reads hook event JSON from stdin, searches SelfMem for relevant memories,
# and prints formatted context + save reminder to stdout.
#
# Prefers the stdlib-only Python implementation (selfmem-recall.py) when
# python3 is available — it has no curl/jq dependency and stricter fail-open
# handling. The shell pipeline below is the fallback.
#
# Environment variables:
#   SELFMEM_URL        — SelfMem server URL (default: https://selfmem.com)
#   SELFMEM_API_KEY    — API key for SelfMem
#   SELFMEM_PROJECT    — Project ID / slug to scope recall to
#   SELFMEM_RECALL_LIMIT — Max results (default: 8)
#
# Fail-open: any error prints only the save reminder and exits 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prefer the Python implementation ───────────────────────────────────────
if command -v python3 &>/dev/null && [ -f "${SCRIPT_DIR}/selfmem-recall.py" ]; then
    exec python3 "${SCRIPT_DIR}/selfmem-recall.py"
fi

# ── Shell fallback ─────────────────────────────────────────────────────────
SELFMEM_URL="${SELFMEM_URL:-https://selfmem.com}"
SELFMEM_RECALL_LIMIT="${SELFMEM_RECALL_LIMIT:-8}"

save_reminder() {
    echo ""
    echo "[selfmem] Before you finish — save anything worth keeping (decisions,"
    echo "  non-obvious facts, user preferences, root causes of fixes)."
    echo ""
}

# If API key or project is missing, print save reminder and exit cleanly.
if [ -z "${SELFMEM_API_KEY:-}" ] || [ -z "${SELFMEM_PROJECT:-}" ]; then
    echo "[selfmem] Not configured. Set SELFMEM_API_KEY and SELFMEM_PROJECT."
    save_reminder
    exit 0
fi

# The fallback needs jq for URL-encoding and response parsing; without it a
# query containing spaces would produce an invalid URL and recall would
# silently never work.
if ! command -v jq &>/dev/null; then
    echo "[selfmem] Recall unavailable (needs python3 or jq)."
    save_reminder
    exit 0
fi

# ── Parse hook input ───────────────────────────────────────────────────────
# Read stdin (hook event JSON). Extract a query string from whatever is
# available: the user prompt, tool input, or tool name.
HOOK_INPUT=$(cat)

QUERY=$(printf '%s' "$HOOK_INPUT" | jq -r '
    .prompt // .tool_input.command // .tool_input.content //
    .tool_input.text  // .tool_name // ""' 2>/dev/null || echo "")

# Fallback: use raw input truncated to 500 chars
if [ -z "$QUERY" ]; then
    QUERY=$(printf '%s' "$HOOK_INPUT" | cut -c1-500)
fi

if [ -z "$QUERY" ]; then
    echo "[selfmem] No query extracted from hook input."
    save_reminder
    exit 0
fi

# printf (not echo) so the query isn't encoded with a trailing %0A
QUERY_ENC=$(printf '%s' "$QUERY" | jq -sRr @uri 2>/dev/null || echo "")
if [ -z "$QUERY_ENC" ]; then
    echo "[selfmem] Recall unavailable (query encoding failed)."
    save_reminder
    exit 0
fi

# ── Call SelfMem recall API ────────────────────────────────────────────────
# max-time 6 stays under the 8s hook timeout so the fail-open path still runs.
RESPONSE=$(curl -s --max-time 6 --fail \
    -H "X-API-Key: ${SELFMEM_API_KEY}" \
    "${SELFMEM_URL}/api/v1/recall?project_id=${SELFMEM_PROJECT}&query=${QUERY_ENC}&limit=${SELFMEM_RECALL_LIMIT}" \
    2>/dev/null) || true

if [ -z "$RESPONSE" ]; then
    # Network error or timeout — fail open
    echo "[selfmem] Recall unavailable (network)."
    save_reminder
    exit 0
fi

# ── Format results ─────────────────────────────────────────────────────────
# Every jq call is guarded: a malformed response (e.g. an HTML error page
# served with HTTP 200) must degrade to the save reminder, never a non-zero
# exit.
ITEMS=$(printf '%s' "$RESPONSE" | jq -c '.items // []' 2>/dev/null || echo '[]')
COUNT=$(printf '%s' "$ITEMS" | jq -r 'length' 2>/dev/null || echo 0)
GROUNDED=$(printf '%s' "$RESPONSE" | jq -r '.confidence.grounded // false' 2>/dev/null || echo false)

if [ "${COUNT:-0}" -gt 0 ] 2>/dev/null; then
    echo "[selfmem recall] ${COUNT} saved memories (grounded=${GROUNDED}):"
    echo ""
    printf '%s' "$ITEMS" | jq -r '
        .[] |
        "  - (\(.memory_type // "memory"), conf=\(.confidence // "?"), recall=\(.recall_score // "?")) \(.content // "")"' \
        2>/dev/null || true
    echo ""

    if [ "$GROUNDED" != "true" ]; then
        echo "[recall grounded=false] Treat as prior context, not absolute fact."
    fi
else
    echo "[selfmem recall] No stored memories matched."
fi

save_reminder
exit 0
