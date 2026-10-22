#!/usr/bin/env bash
# Vérifications locales : tests Luau (Lune), analyse de types Roblox (luau-lsp), construction de la place (Rojo).
# Outils attendus dans le PATH ou dans $TOOLS : lune, luau-lsp, rojo ; définitions Roblox dans $ROBLOX_TYPES.
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-}"
bin() { if [ -n "$TOOLS" ] && [ -x "$TOOLS/$1" ]; then echo "$TOOLS/$1"; else command -v "$1"; fi; }
TYPES="${ROBLOX_TYPES:-globalTypes.d.luau}"

echo "== Tests =="
"$(bin lune)" run tools/tests/run.luau .

echo "== Interface et contrôleurs (banc d'essai Lune) =="
"$(bin lune)" run tools/tests/ui_smoke.luau .

echo "== Analyse de types =="
"$(bin rojo)" sourcemap default.project.json -o sourcemap.json >/dev/null
"$(bin luau-lsp)" analyze --definitions="$TYPES" --sourcemap=sourcemap.json --no-strict-dm-types \
	--ignore="**/Voxel/Models/**" src

echo "== Construction =="
mkdir -p build
"$(bin rojo)" build default.project.json -o build/ValoriaChampions.rbxl
echo "OK"
