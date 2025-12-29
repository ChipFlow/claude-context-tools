# Regenerate Repository Map

Regenerate the repo map for this project to understand the code structure, find similar classes/functions, and identify documentation gaps.

Run this command to regenerate with progress display:

```bash
# Kill any existing repo-map process
LOCK_FILE=".claude/repo-map-cache.lock"
if [[ -f "${LOCK_FILE}" ]]; then
    OLD_PID=$(cat "${LOCK_FILE}" 2>/dev/null)
    if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
        echo "Stopping existing repo-map process (PID ${OLD_PID})..."
        kill "${OLD_PID}" 2>/dev/null
        sleep 1
    fi
    rm -f "${LOCK_FILE}"
fi

# Run any cache format migrations (clears cache if incompatible version)
python3 -c "
import json
from pathlib import Path

CURRENT_VERSION = 2  # Must match CACHE_VERSION in generate-repo-map.py

cache_path = Path('.claude/repo-map-cache.json')
if cache_path.exists():
    try:
        data = json.loads(cache_path.read_text())
        version = data.get('version', 0)
        if version != CURRENT_VERSION:
            # Add migration logic here when format changes
            # For now, just clear incompatible caches
            print(f'Cache version {version} != {CURRENT_VERSION}, clearing...')
            cache_path.unlink()
    except (json.JSONDecodeError, KeyError):
        print('Corrupt cache, clearing...')
        cache_path.unlink()
" 2>/dev/null

# Clear output file (but keep cache for incremental updates)
rm -f .claude/repo-map.md
nohup uv run ${CLAUDE_PLUGIN_ROOT}/scripts/generate-repo-map.py > .claude/repo-map-build.log 2>&1 &

# Show progress until complete (only print when status changes)
echo "Regenerating repo map..."
LAST_PROGRESS=""
while true; do
    if [[ -f .claude/repo-map-progress.json ]]; then
        PROGRESS=$(python3 -c "
import json
try:
    with open('.claude/repo-map-progress.json') as f:
        p = json.load(f)
    status = p.get('status', 'unknown')
    if status == 'complete':
        print(f\"Complete: {p.get('symbols_found', 0)} symbols found\")
    elif status == 'indexing':
        total = p.get('files_total', 0)
        done = p.get('files_cached', 0) + p.get('files_parsed', 0)
        pct = (done / total * 100) if total > 0 else 0
        print(f\"Indexing: {pct:.0f}% ({done}/{total} files)\")
    else:
        print(f\"Status: {status}\")
except Exception as e:
    print(f'Starting...')
" 2>/dev/null)
        if [[ "${PROGRESS}" != "${LAST_PROGRESS}" ]]; then
            echo "${PROGRESS}"
            LAST_PROGRESS="${PROGRESS}"
        fi
        if [[ "${PROGRESS}" == Complete* ]]; then
            break
        fi
    fi
    sleep 1
done

# Show summary with clash count
if [[ -f .claude/repo-map.md ]]; then
    CLASH_COUNT=$(grep -c "^- \*\*" .claude/repo-map.md 2>/dev/null | head -1 || echo "0")
    echo "Repo map saved to .claude/repo-map.md"
    if [[ "${CLASH_COUNT}" -gt 0 ]]; then
        echo "${CLASH_COUNT} potential naming clash(es) detected."
        echo "Run /clash-summary for overview or /resolve-clashes to review interactively."
    fi
fi
```

After running, review the output for:
- **Similar classes**: May indicate overlapping responsibilities or duplicate implementations (same-language only)
- **Similar functions**: May be candidates for consolidation (same-language only)
- **Undocumented code**: Opportunities to improve codebase understanding

Note: Cross-language similarities (e.g., Python and Rust) are not flagged as they're typically intentional (bindings, ports).

If clashes are detected, use `/clash-summary` for an overview or `/resolve-clashes` to review and resolve them interactively.
