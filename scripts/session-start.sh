#!/usr/bin/env bash
# Session Start Hook for context-tools plugin
# Runs when a new Claude Code session starts
# Generates project manifest and starts repo map generation in background

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PWD}"
CLAUDE_DIR="${PROJECT_ROOT}/.claude"

# Ensure .claude directory exists
mkdir -p "${CLAUDE_DIR}"

# Generate project manifest (quick, runs synchronously)
uv run "${SCRIPT_DIR}/generate-manifest.py" "${PROJECT_ROOT}" 2>/dev/null || true

# Start repo map generation in background (can take a while for large projects)
# Uses lock file to prevent concurrent runs
# Progress is saved periodically, so safe to interrupt
(
    nohup uv run "${SCRIPT_DIR}/generate-repo-map.py" "${PROJECT_ROOT}" \
        > "${CLAUDE_DIR}/repo-map-build.log" 2>&1 &
) &

# Display project context if manifest exists
MANIFEST="${PROJECT_ROOT}/.claude/project-manifest.json"
if [[ -f "${MANIFEST}" ]]; then
    echo "=== Project Context ==="

    # Extract key info using python for JSON parsing
    python3 -c "
import json
import sys
try:
    with open('${MANIFEST}') as f:
        m = json.load(f)
    print(f\"Project: {m.get('project_name', 'unknown')}\")
    langs = m.get('languages', [])
    if langs:
        print(f\"Languages: {', '.join(langs)}\")
    build = m.get('build_system', {})
    if build.get('type'):
        print(f\"Build: {build['type']}\")
        if build.get('commands'):
            cmds = build['commands']
            if cmds.get('build'):
                print(f\"  Build: {cmds['build']}\")
            if cmds.get('test'):
                print(f\"  Test: {cmds['test']}\")
    entries = m.get('entry_points', [])
    if entries:
        print(f\"Entry points: {', '.join(entries[:3])}\")
except Exception as e:
    pass
" 2>/dev/null || true

    echo "========================"
fi

# Check for project learnings
LEARNINGS="${PROJECT_ROOT}/.claude/learnings.md"
if [[ -f "${LEARNINGS}" ]]; then
    LEARNING_COUNT=$(grep -c "^## " "${LEARNINGS}" 2>/dev/null || echo "0")
    if [[ "${LEARNING_COUNT}" -gt 0 ]]; then
        echo ""
        echo "📚 ${LEARNING_COUNT} project learning(s) available in .claude/learnings.md"
    fi
fi

# Check for global learnings
GLOBAL_LEARNINGS="${HOME}/.claude/learnings.md"
if [[ -f "${GLOBAL_LEARNINGS}" ]]; then
    GLOBAL_COUNT=$(grep -c "^## " "${GLOBAL_LEARNINGS}" 2>/dev/null || echo "0")
    if [[ "${GLOBAL_COUNT}" -gt 0 ]]; then
        echo "🌍 ${GLOBAL_COUNT} global learning(s) available in ~/.claude/learnings.md"
    fi
fi

# Show repo map status
REPO_MAP="${CLAUDE_DIR}/repo-map.md"
REPO_MAP_CACHE="${CLAUDE_DIR}/repo-map-cache.json"
if [[ -f "${REPO_MAP}" ]]; then
    SYMBOL_COUNT=$(grep -c "^\*\*" "${REPO_MAP}" 2>/dev/null || echo "0")
    echo "🗺️  Repo map available (${SYMBOL_COUNT} symbols)"
    # Check if cache exists and if we're rebuilding
    if [[ -f "${CLAUDE_DIR}/repo-map-cache.lock" ]]; then
        echo "   ⏳ Updating in background..."
    fi
else
    echo "🗺️  Building repo map in background..."
fi
