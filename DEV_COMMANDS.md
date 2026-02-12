# Comandos de desarrollo

## Ejecutar juego (headless)
godot --headless --path . --main-scene res://scenes/Main.tscn --quit

## Ver errores de scripts
godot --headless --path . --quit --check-only

## Ejecutar smoke test
godot --headless --path . --quit --script res://tools/test_smoke.gd

## Git workflow
git status
git add .
git commit -m "mensaje"
git push
