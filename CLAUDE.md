# Context Tools Plugin Development

## Version Bumping

**IMPORTANT: Always bump the version when making changes!**

Update version in BOTH files:
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

Users need to run `claude plugin update` to get changes, and this only works if the version number increases.

## Testing Changes Locally

```bash
# Test with --plugin-dir (no install needed)
claude --plugin-dir /path/to/context-tools

# Or run scripts directly
uv run scripts/generate-repo-map.py /path/to/test-project
uv run scripts/generate-manifest.py /path/to/test-project
```

## Hook Structure

When using matchers in hooks.json, the structure requires a nested `hooks` array:

```json
{
  "matcher": "startup",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"
    }
  ]
}
```

## Output Behavior

- **SessionStart hook**: stdout goes to Claude's context, stderr is displayed to user
- Use `>&2` to show messages to the user: `echo "message" >&2`

## CI

- Main CI validates structure and tests scripts
- E2E tests require `ANTHROPIC_API_KEY` secret (skipped if not set)
