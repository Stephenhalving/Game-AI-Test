#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dev/aiops/projects/trumpquest/godot"
cd "$PROJECT_ROOT"

DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
OUT_DIR="AI_MEMORY/daily"
OUT_FILE="${OUT_DIR}/${DATE}.md"

mkdir -p "$OUT_DIR"

# Si ya existe el daily de hoy, no lo pisa; agrega una entrada nueva
{
  echo ""
  echo "## Daily Log Entry - ${DATE} ${TIME}"
  echo ""
  echo "### Repo Status"
  echo "- Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
  echo "- Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
  echo "- Dirty: $(git diff --quiet 2>/dev/null && echo 'no' || echo 'yes')"
  echo ""
  echo "### Recent Commits (last 5)"
  git --no-pager log -n 5 --oneline 2>/dev/null || echo "N/A"
  echo ""
  echo "### Project Health Checks"
  echo "- Headless script check:"
  if command -v godot >/dev/null 2>&1; then
    godot --headless --path . --quit --check-only >/dev/null 2>&1 && echo "  - OK" || echo "  - FAIL (check logs/manual run)"
  else
    echo "  - Godot CLI not found in PATH (skipped)"
  fi
  echo ""
  echo "### Notes"
  echo "- (optional) Add manual notes here"
  echo ""
} >> "$OUT_FILE"

echo "✅ Daily log updated: $OUT_FILE"
