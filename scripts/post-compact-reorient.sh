#!/usr/bin/env bash
# Post-Compaction Reorientation Hook
# Runs on UserPromptSubmit to inject context after compaction

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PWD}"
CLAUDE_DIR="${PROJECT_ROOT}/.claude"
FLAG_FILE="${CLAUDE_DIR}/needs-reorientation"
DB_FILE="${CLAUDE_DIR}/repo-map.db"
LEARNINGS_FILE="${CLAUDE_DIR}/learnings.md"

# Read the original prompt from stdin
ORIGINAL_PROMPT=$(cat)

# If no reorientation needed, pass through unchanged
if [[ ! -f "${FLAG_FILE}" ]]; then
    PROMPT_ESCAPED=$(echo -n "$ORIGINAL_PROMPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//')
    cat << EOF
{
  "allow": true,
  "prompt": "${PROMPT_ESCAPED}"
}
EOF
    exit 0
fi

# Remove flag immediately (so we only do this once)
rm -f "${FLAG_FILE}"

# Build reorientation context in clean markdown
CONTEXT="🔄 **Context Restored After Compaction**\n"
CONTEXT="${CONTEXT}\n## MCP Tools Available"
CONTEXT="${CONTEXT}\n- \`search_symbols(\"TypeName\")\` - Find symbols by pattern"
CONTEXT="${CONTEXT}\n- \`get_symbol_content(\"TypeName\")\` - Get full symbol source code"
CONTEXT="${CONTEXT}\n- \`list_files(\"*.py\")\` - List indexed files by pattern"
CONTEXT="${CONTEXT}\n\n*10-100x faster than Search/Grep/find for code structure queries*"

# Add project structure from repo map if available
if [[ -f "${DB_FILE}" ]]; then
    # Get top-level directories with file counts
    DIRS=$(sqlite3 "${DB_FILE}" "
        SELECT
            CASE
                WHEN file_path LIKE '%/%' THEN substr(file_path, 1, instr(file_path, '/') - 1)
                ELSE '.'
            END as dir,
            COUNT(*) as cnt
        FROM symbols
        WHERE file_path != ''
        GROUP BY dir
        ORDER BY cnt DESC
        LIMIT 10
    " 2>/dev/null || echo "")

    if [[ -n "${DIRS}" ]]; then
        CONTEXT="${CONTEXT}\n\n## Project Structure"
        while IFS='|' read -r dir count; do
            if [[ "${dir}" == "." ]]; then
                CONTEXT="${CONTEXT}\n- Root directory (${count} symbols)"
            else
                CONTEXT="${CONTEXT}\n- \`${dir}/\` (${count} symbols)"
            fi
        done <<< "${DIRS}"
    fi

    # Get key components (classes and major functions)
    CLASSES=$(sqlite3 "${DB_FILE}" "
        SELECT name, file_path, line_number
        FROM symbols
        WHERE kind = 'class'
        ORDER BY RANDOM()
        LIMIT 5
    " 2>/dev/null || echo "")

    FUNCTIONS=$(sqlite3 "${DB_FILE}" "
        SELECT name, file_path, line_number
        FROM symbols
        WHERE kind = 'function'
        ORDER BY RANDOM()
        LIMIT 5
    " 2>/dev/null || echo "")

    if [[ -n "${CLASSES}" ]] || [[ -n "${FUNCTIONS}" ]]; then
        CONTEXT="${CONTEXT}\n\n## Key Components"

        if [[ -n "${CLASSES}" ]]; then
            while IFS='|' read -r name path line; do
                CONTEXT="${CONTEXT}\n- **${name}** (class) - \`${path}:${line}\`"
            done <<< "${CLASSES}"
        fi

        if [[ -n "${FUNCTIONS}" ]]; then
            while IFS='|' read -r name path line; do
                CONTEXT="${CONTEXT}\n- **${name}()** (function) - \`${path}:${line}\`"
            done <<< "${FUNCTIONS}"
        fi
    fi
fi

# Add recent learnings if available
if [[ -f "${LEARNINGS_FILE}" ]]; then
    LEARNING_COUNT=$(grep -c "^### " "${LEARNINGS_FILE}" 2>/dev/null || echo "0")
    if [[ "${LEARNING_COUNT}" -gt 0 ]]; then
        CONTEXT="${CONTEXT}\n\n## Recent Work (from learnings.md)"
        # Get last 5 learning titles
        RECENT=$(grep "^### " "${LEARNINGS_FILE}" | tail -5 || echo "")
        if [[ -n "${RECENT}" ]]; then
            while IFS= read -r title; do
                # Remove the ### prefix for cleaner display
                clean_title=$(echo "$title" | sed 's/^### //')
                CONTEXT="${CONTEXT}\n- ${clean_title}"
            done <<< "${RECENT}"
        fi

        if [[ "${LEARNING_COUNT}" -gt 5 ]]; then
            CONTEXT="${CONTEXT}\n\n*See .claude/learnings.md for all ${LEARNING_COUNT} entries*"
        fi
    fi
fi

# Prepend context to the original prompt
MODIFIED_PROMPT="${CONTEXT}\n\n---\n\n${ORIGINAL_PROMPT}"

# Escape for JSON
PROMPT_ESCAPED=$(echo -e "$MODIFIED_PROMPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//')

# Return JSON with modified prompt
cat << EOF
{
  "allow": true,
  "prompt": "${PROMPT_ESCAPED}"
}
EOF
