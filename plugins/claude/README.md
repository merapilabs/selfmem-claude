# SelfMem Claude Code Plugin

Persistent, self-learning memory for Claude Code — auto-recall, auto-save, semantic search, and knowledge graph, all in one plugin.

## How It Works

- **Auto-recall** — before each turn, the plugin searches SelfMem for relevant memories and injects them as context. Grounded/ungrounded confidence banners help you calibrate trust.
- **Auto-save nudging** — after each turn, a friendly reminder nudges the agent to persist anything worth keeping (decisions, non-obvious facts, user preferences, root causes).
- **MCP tools** — the agent gets `save_memory`, `search_memory`, `update_memory`, `delete_memory`, and more as native tools via MCP.
- **Knowledge graph** — memories are linked into a graph. Consolidated atoms, scenarios, and personas surface over time as the knowledge pyramid builds.

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
| `selfmem-recall.sh` | `hooks/selfmem-recall.sh` | Shell recall hook (uses curl + jq, fail-open) |
| `selfmem-recall.py` | `hooks/selfmem-recall.py` | Python recall hook (stdlib only, fail-open) |

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
