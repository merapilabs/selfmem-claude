#!/usr/bin/env bash
# selfmem-recall.sh — Claude Code recall hook (shell)
#
# Reads hook event JSON from stdin, searches SelfMem for relevant memories,
# and prints formatted context + save reminder to stdout.
#
# Environment variables:
#   SELFMEM_URL        — SelfMem server URL (default: https://selfmem.com)
#   SELFMEM_API_KEY    — API key for SelfMem
#   SELFMEM_PROJECT    — Project ID / slug to scope recall to
#   SELFMEM_RECALL_LIMIT — Max results (default: 8)
#
# Fail-open: any error prints only the save reminder and exits 0.

set -euo pipefail

# ── Config from env ────────────────────────────────────────────────────────
SELFMEM_URL="${SELFMEM_URL:-https://selfmem.com}"
SELFMEM_RECALL_LIMIT="${SELFMEM_RECALL_LIMIT:-8}"

# ── Fail-open guard ────────────────────────────────────────────────────────
# If API key or project is missing, print save reminder and exit cleanly.
if [ -z "${SELFMEM_API_KEY:-}" ] || [ -z "${SELFMEM_PROJECT:-}" ]; then
    echo "[selfmem] Not configured. Set SELFMEM_API_KEY and SELFMEM_PROJECT."
    echo "[selfmem] Before you finish — save anything worth keeping."
    exit 0
fi

# ── Parse hook input ───────────────────────────────────────────────────────
# Read stdin (hook event JSON). Extract a query string from whatever is
# available: the user prompt, tool input, or tool name.
HOOK_INPUT=$(cat)

QUERY=""
if command -v jq &>/dev/null; then
    # Try to extract 'prompt' (UserPromptSubmit) or tool input content
    QUERY=$(echo "$HOOK_INPUT" | jq -r '
        .prompt // .tool_input.command // .tool_input.content //
        .tool_input.text  // .tool_name // ""' 2>/dev/null || echo "")
fi

# Fallback: use raw input truncated to 500 chars
if [ -z "$QUERY" ]; then
    QUERY=$(echo "$HOOK_INPUT" | cut -c1-500)
fi

if [ -z "$QUERY" ]; then
    echo "[selfmem] No query extracted from hook input."
    exit 0
fi

# ── Call SelfMem recall API ────────────────────────────────────────────────
RESPONSE=$(curl -s --max-time 8 --fail \
    -H "X-API-Key: ${SELFMEM_API_KEY}" \
    "${SELFMEM_URL}/api/v1/recall?project_id=${SELFMEM_PROJECT}&query=$(echo "$QUERY" | jq -sRr @uri)&limit=${SELFMEM_RECALL_LIMIT}" \
    2>/dev/null) || true

if [ -z "$RESPONSE" ]; then
    # Network error or timeout — fail open
    echo "[selfmem] Recall unavailable (network)."
    echo "[selfmem] Before you finish — save anything worth keeping."
    exit 0
fi

# ── Format results ─────────────────────────────────────────────────────────
if command -v jq &>/dev/null; then
    ITEMS=$(echo "$RESPONSE" | jq -r '.items // []')
    COUNT=$(echo "$ITEMS" | jq -r 'length' 2>/dev/null || echo 0)
    GROUNDED=$(echo "$RESPONSE" | jq -r '.confidence.grounded // false' 2>/dev/null)

    if [ "$COUNT" -gt 0 ]; then
        echo "[selfmem recall] ${COUNT} saved memories (grounded=${GROUNDED}):"
        echo ""
        echo "$ITEMS" | jq -r '
            .[] |
            "  - (\(.memory_type // "memory"), conf=\(.confidence // "?"), recall=\(.recall_score // "?")) \(.content // "")"'
        echo ""

        if [ "$GROUNDED" != "true" ]; then
            echo "[recall grounded=false] Treat as prior context, not absolute fact."
        fi
    else
        echo "[selfmem recall] No stored memories matched."
    fi
else
    # Raw output fallback (no jq)
    echo "[selfmem recall] $(echo "$RESPONSE" | cut -c1-1000)"
fi

echo ""
echo "[selfmem] Before you finish — save anything worth keeping (decisions,"
echo "  non-obvious facts, user preferences, root causes of fixes)."
echo ""
exit 0
