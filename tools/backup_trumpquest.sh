#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/dev/aiops/projects/trumpquest/godot"
cd "$PROJECT_ROOT"

DATE="$(date +%F)"
BACKUP_DIR="backups"
OUT_FILE="${BACKUP_DIR}/trumpquest_backup_${DATE}.zip"

mkdir -p "$BACKUP_DIR"

# Qué respaldar
INCLUDE=(
  "AI_MEMORY"
  "scripts"
  "scenes"
  "project.godot"
)

# Crear zip con excludes típicos de Godot
zip -r "$OUT_FILE" "${INCLUDE[@]}" \
  -x "**/.godot/**" \
  -x "**/.import/**" \
  -x "**/*.uid" \
  -x "**/*.tmp" \
  -x "**/*.log" >/dev/null

echo "✅ Backup creado: $OUT_FILE"

# Retención: últimos 30 backups
ls -1t ${BACKUP_DIR}/trumpquest_backup_*.zip 2>/dev/null | tail -n +31 | xargs -r rm -f
echo "🧹 Retención aplicada: últimos 30 backups"
