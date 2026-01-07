---
name: setup-mcp
description: Configure the MCP server for fast symbol lookups across all projects
---

# Setup MCP Server

This command configures the repo-map MCP server globally so you have fast symbol search tools available.

## What This Does

Adds the `repo-map` MCP server to your Claude Code configuration with these tools:
- `search_symbols` - Find functions/classes/methods by pattern (e.g., `get_*`, `*Handler`)
- `get_file_symbols` - List all symbols in a file
- `get_symbol_content` - Get full source code of a symbol
- `reindex_repo_map` - Trigger manual reindex
- `repo_map_status` - Check indexing status

## Steps

1. Get the plugin version:
```bash
PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('${HOME}/.claude/plugins/cache/chipflow-context-tools/context-tools/.claude-plugin/plugin.json'))['version'])")
```

2. Add the MCP server:
```bash
claude mcp add --scope user --transport stdio repo-map \
  --env PROJECT_ROOT='${PWD}' \
  -- uv run "${HOME}/.claude/plugins/cache/chipflow-context-tools/context-tools/${PLUGIN_VERSION}/servers/repo-map-server.py"
```

3. Verify it's configured:
```bash
claude mcp list
```

You should see: `repo-map: ... - ✓ Connected`

## After Setup

**Restart Claude Code** for the MCP server to load.

After restart, the MCP tools will be available in all projects. The server automatically:
- Indexes your codebase on first use
- Monitors for file changes and reindexes
- Stores symbols in `.claude/repo-map.db`

## Troubleshooting

If `claude mcp list` shows an error:
- Check that `uv` is installed: `uv --version`
- Verify the plugin is installed: `claude plugin list`
- Check the plugin cache path exists: `ls ~/.claude/plugins/cache/chipflow-context-tools/context-tools/`

## To Remove

```bash
claude mcp remove repo-map
```
