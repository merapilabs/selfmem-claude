# selfmem-claude

Public marketplace for the **SelfMem** Claude Code plugin — persistent, self-learning memory for Claude Code (auto-recall, auto-save, semantic search, and knowledge graph).

This repo contains **only** the Claude Code plugin + marketplace catalog, so anyone can install it without access to the full [SelfMem](https://github.com/merapilabs/selfmem) product repo.

## Install

```
/plugin marketplace add merapilabs/selfmem-claude
/plugin install selfmem-claude@selfmem-plugins
```

Then configure your API key and project (see the [plugin README](plugins/claude/README.md)):

```bash
export SELFMEM_API_KEY="sm_..."
export SELFMEM_PROJECT="your-project"
export SELFMEM_URL="https://selfmem.com"   # optional, default
```

## Layout

```
.claude-plugin/
└── marketplace.json          # marketplace catalog (lists selfmem-claude)
plugins/claude/
├── .claude-plugin/plugin.json  # plugin manifest (MCP server + recall hook)
├── hooks/                       # fail-open recall hooks (shell + python)
└── README.md                    # full plugin docs
```

## Links

- [Plugin documentation](plugins/claude/README.md)
- [SelfMem](https://selfmem.com) — hosted service
- [Claude Code plugin docs](https://code.claude.com/docs/en/plugins)
