# SelfMem Claude Code Plugin

Persistent, self-learning memory for Claude Code — auto-recall, auto-save, semantic search, and knowledge graph, all in one plugin.

## How It Works

- **Auto-recall** — before each turn, the plugin searches SelfMem for relevant memories and injects them as context. Grounded/ungrounded confidence banners help you calibrate trust.
- **Auto-save nudging** — after each turn, a friendly reminder nudges the agent to persist anything worth keeping (decisions, non-obvious facts, user preferences, root causes).
- **MCP tools** — the agent gets `save_memory`, `search_memory`, `update_memory`, `delete_memory`, and more as native tools via MCP. See [MCP Tools](#mcp-tools) for the full list.
- **Knowledge graph** — memories are linked into a graph. Consolidated atoms, scenarios, and personas surface over time as the knowledge pyramid builds.

## MCP Tools

The `selfmem` MCP server exposes these tools to the agent:

| Tool | Description |
|---|---|
| `save_memory` | Save a memory to a project (typed: generic, user, feedback, project, reference, incident, runbook) |
| `search_memory` | Semantic search over stored memories |
| `list_memories` | List memories in a project, optionally filtered by type |
| `get_memory` | Fetch a specific memory by ID, with its graph relations |
| `update_memory` | Update an existing memory (re-embeds if content changes) |
| `delete_memory` | Soft-delete a memory (moves to archive) |
| `link_memory` / `unlink_memory` | Add or remove manual graph edges between memories |
| `graph_search` | Graph-aware search across linked memories |
| `auto_recall` | On-demand recall — same behavior as the recall hook, callable by the agent |
| `auto_save` | Dedup-aware save: searches for near-duplicates first, suggests updating instead of duplicating |
| `schedule_consolidation` | Schedule a consolidation pass (build atoms/scenarios from raw memories) |
| `trigger_reflection` | Trigger a reflection pass over a project |
| `request_forgetting` | Request decay/forgetting of stale memories |

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- A [SelfMem](https://github.com/merapilabs/selfmem) instance (hosted at selfmem.com or self-hosted)
- An API key from SelfMem

## Quick Install

### Option 1: From the marketplace (recommended)

Add the SelfMem plugin marketplace and install the plugin:

```
/plugin marketplace add merapilabs/selfmem-claude
/plugin install selfmem-claude@selfmem-plugins
```

### Option 2: Local install from the repo

```
git clone https://github.com/merapilabs/selfmem-claude.git
/plugin marketplace add ./selfmem-claude
/plugin install selfmem-claude@selfmem-plugins
```

## Configuration

After installing, set the required environment variables:

```bash
export SELFMEM_API_KEY="sm_..."          # Your SelfMem API key
export SELFMEM_PROJECT="your-project"    # Project slug from SelfMem
export SELFMEM_URL="https://selfmem.com" # SelfMem server (optional, default)
```

`SELFMEM_URL` applies to both the recall hook and the MCP server connection, so a self-hosted instance only needs the one variable.

Or add them to `.claude/settings.local.json`:

```json
{
  "env": {
    "SELFMEM_API_KEY": "sm_...",
    "SELFMEM_PROJECT": "your-project",
    "SELFMEM_URL": "https://selfmem.com"
  }
}
```

### Getting an API key

- **Hosted**: Sign up at https://selfmem.com → API key is provisioned automatically
- **Self-hosted**: Visit `http://your-selfmem:8818/ui/account/keys` to create a key

## Plugin Components

| Component | Path | Description |
|---|---|---|
| `selfmem` MCP server | plugin.json `mcpServers` | Connects to SelfMem via `mcp-remote` + `X-API-Key` header |
| `selfmem-recall.sh` | `hooks/selfmem-recall.sh` | Recall hook entrypoint — delegates to the Python hook when `python3` is available, otherwise falls back to a curl + jq pipeline (fail-open) |
| `selfmem-recall.py` | `hooks/selfmem-recall.py` | Python recall hook (stdlib only, fail-open) — the preferred implementation |

The recall hook fires on `UserPromptSubmit` — when you send a message, it searches SelfMem for relevant memories and prints them as context for that turn. It always fails open (any error → prints save reminder only).

## Verifying It Works

1. Start a Claude Code session
2. Ask: "What do you know about this project from previous sessions?"
3. If the recall hook fires, you'll see `[selfmem recall] N stored memories ...`
4. The agent can also call `search_memory` directly as an MCP tool

Check status:

```
/plugin list
# Should show: selfmem-claude@selfmem-plugins — enabled
```

## Fail-Open Design

The recall hook never blocks Claude Code. If:
- The API key is missing → prints a config reminder, exits 0
- The SelfMem server is unreachable → prints "Recall unavailable", exits 0
- The response is malformed → prints a save reminder, exits 0
- Anything else goes wrong → prints a save reminder, exits 0

The payload always includes the standing save nudge, so you still get prompted to persist knowledge even when recall is down.

## Troubleshooting

**MCP server connects but tools fail with auth errors** — check that `SELFMEM_API_KEY` is exported in the shell that launches Claude Code (or set in `.claude/settings.local.json` under `env`). The plugin manifest passes `${SELFMEM_API_KEY}` through to the `X-API-Key` header; if the variable is unset, the header is sent empty.

**Recall hook prints "Not configured"** — both `SELFMEM_API_KEY` and `SELFMEM_PROJECT` must be set. The hook fails open, so Claude Code keeps working either way.

**Self-hosted instance not being used** — set `SELFMEM_URL` before starting Claude Code. Restart the session after changing it; MCP servers are spawned at session start.

## Uninstalling

```
/plugin uninstall selfmem-claude
/plugin marketplace remove selfmem-plugins
```

## For Developers

### Testing the recall hook locally

```bash
# Simulate a hook event (JSON on stdin)
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
  SELFMEM_URL=https://selfmem.com \
  SELFMEM_API_KEY=sm_test \
  SELFMEM_PROJECT=test-project \
  bash hooks/selfmem-recall.sh
```

### Plugin structure

```
plugins/claude/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (MCP server + hooks)
├── hooks/
│   ├── selfmem-recall.sh    # Shell recall hook
│   └── selfmem-recall.py    # Python recall hook
└── README.md                # This file
```

### Marketplace catalog

The marketplace is defined at the repo root:

```
.claude-plugin/
└── marketplace.json         # Marketplace catalog listing selfmem-claude
```

## See Also

- [SelfMem GitHub](https://github.com/merapilabs/selfmem) — main repository
- [SelfMem Website](https://selfmem.com) — hosted service
- [Claude Code Plugin Docs](https://code.claude.com/docs/en/plugins) — official plugin guide
- [Hermes Integration](https://github.com/merapilabs/selfmem/blob/master/plugins/hermes/README.md) — Hermes Agent native plugin
