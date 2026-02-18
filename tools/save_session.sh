#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dev/aiops/projects/trumpquest/godot"
cd "$PROJECT_ROOT"

if [ $# -lt 1 ]; then
  echo "Uso: $0 \"titulo_corto_sesion\""
  echo "Ej:  $0 \"arena fixes + enemy tuning\""
  exit 1
fi

TITLE="$1"
DATE="$(date +%F)"
TIME="$(date +%H%M%S)"
SAFE_TITLE="$(echo "$TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')"

OUT_DIR="AI_MEMORY/sessions"
OUT_FILE="${OUT_DIR}/${DATE}_${TIME}_${SAFE_TITLE}.md"

mkdir -p "$OUT_DIR"

{
  echo "# Session: ${TITLE}"
  echo ""
  echo "- Date: ${DATE}"
  echo "- Time: ${TIME}"
  echo ""
  echo "## Session Summary"
  echo ""
  echo "(Pegá acá el resumen. Terminá con CTRL+D)"
  echo ""
} > "$OUT_FILE"

cat >> "$OUT_FILE"

echo ""
echo "✅ Guardado: $OUT_FILE"
