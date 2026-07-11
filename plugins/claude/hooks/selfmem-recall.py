#!/usr/bin/env python3
"""selfmem-recall.py — Claude Code recall hook (Python)

Reads hook event JSON from stdin, searches SelfMem for relevant memories,
and prints formatted context + save reminder to stdout.

Environment variables:
  SELFMEM_URL            — SelfMem server URL (default: https://selfmem.com)
  SELFMEM_API_KEY        — API key for SelfMem
  SELFMEM_PROJECT        — Project ID / slug to scope recall to
  SELFMEM_RECALL_LIMIT   — Max results (default: 8)

Fail-open: any error prints only the save reminder and exits 0.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

# ── Config from env ────────────────────────────────────────────────────────
SELFMEM_URL = os.environ.get("SELFMEM_URL", "https://selfmem.com").rstrip("/")
SELFMEM_API_KEY = os.environ.get("SELFMEM_API_KEY", "")
SELFMEM_PROJECT = os.environ.get("SELFMEM_PROJECT", "")
SELFMEM_RECALL_LIMIT = int(os.environ.get("SELFMEM_RECALL_LIMIT", "8"))


def emit_save_reminder() -> None:
    """Print the standing save-nudge reminder."""
    print("[selfmem] Before you finish — save anything worth keeping (decisions,")
    print("  non-obvious facts, user preferences, root causes of fixes).")
    print()


def fail_open(msg: str = "") -> None:
    """Fail gracefully: print message + save reminder, exit 0."""
    if msg:
        print(f"[selfmem] {msg}")
    emit_save_reminder()
    sys.exit(0)


def extract_query(hook_input: dict) -> str:
    """Extract a usable query string from the hook event JSON.

    Claude Code sends different fields depending on the hook event
    (UserPromptSubmit → .prompt, PostToolUse → .tool_input, etc.).
    We try several in priority order and take the first non-empty hit.
    """
    candidates = [
        hook_input.get("prompt"),
        hook_input.get("query"),
        hook_input.get("content"),
    ]

    # Tool input can be a dict or string
    tool_input = hook_input.get("tool_input", {})
    if isinstance(tool_input, dict):
        candidates.extend(
            [
                tool_input.get("content"),
                tool_input.get("text"),
                tool_input.get("command"),
                tool_input.get("description"),
            ]
        )
    elif isinstance(tool_input, str):
        candidates.append(tool_input)

    candidates.append(hook_input.get("tool_name"))

    for c in candidates:
        if c and isinstance(c, str) and c.strip():
            return c.strip()[:500]

    # Last resort: use the raw JSON as query text
    raw = json.dumps(hook_input)
    return raw[:500]


def call_recall(query: str) -> dict | None:
    """Call the SelfMem recall REST API. Returns parsed JSON or None on error."""
    params = urllib.parse.urlencode(
        {
            "project_id": SELFMEM_PROJECT,
            "query": query,
            "limit": SELFMEM_RECALL_LIMIT,
        }
    )
    url = f"{SELFMEM_URL}/api/v1/recall?{params}"

    req = urllib.request.Request(url)
    req.add_header("X-API-Key", SELFMEM_API_KEY)

    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError):
        return None


def format_results(data: dict) -> None:
    """Print formatted recall results to stdout."""
    items = data.get("items", [])
    confidence = data.get("confidence", {})
    grounded = confidence.get("grounded", False)
    top_score = confidence.get("top_score", 0.0)

    if not items:
        print("[selfmem recall] No stored memories matched.")
        print()
        return

    count = len(items)
    persona = data.get("persona")
    persona_line = ""
    if persona:
        persona_line = "; persona available"

    print(f"[selfmem recall] {count} stored memories "
          f"(grounded={grounded}, top_score={top_score}{persona_line}):")
    print()

    for item in items:
        mem_type = item.get("memory_type", "memory")
        conf = item.get("confidence", "?")
        recall = item.get("recall_score", "?")
        content = item.get("content", "")
        print(f"  - ({mem_type}, conf={conf}, recall={recall}) {content}")

    print()

    if not grounded:
        print("[recall grounded=false] Treat as prior context, not absolute fact; "
              "verify before relying on them.")
        print()


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> None:
    # Guard: require API key + project
    if not SELFMEM_API_KEY:
        return fail_open("Not configured. Set SELFMEM_API_KEY and SELFMEM_PROJECT.")

    if not SELFMEM_PROJECT:
        return fail_open("Not configured. Set SELFMEM_PROJECT.")

    # Read hook event JSON from stdin
    raw_stdin = sys.stdin.read()
    if not raw_stdin.strip():
        return fail_open("No hook input received.")

    try:
        hook_input = json.loads(raw_stdin)
    except json.JSONDecodeError:
        # Not JSON — use raw text as query
        hook_input = {}

    # Extract query
    query = extract_query(hook_input)
    if not query and raw_stdin.strip():
        query = raw_stdin.strip()[:500]

    if not query:
        return fail_open("No query extracted from hook input.")

    # Call recall API
    data = call_recall(query)
    if data is None:
        return fail_open("Recall unavailable (network).")

    # Format and print
    format_results(data)
    emit_save_reminder()


if __name__ == "__main__":
    main()
