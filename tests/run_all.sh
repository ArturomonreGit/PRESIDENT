#!/usr/bin/env bash
# Ejecuta todas las pruebas. Uso: GODOT=/ruta/godot tests/run_all.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
fail=0
python3 tests/check_dataset.py || fail=1
python3 tests/test_dhondt_reference.py || fail=1
"$GODOT" --headless --path . --import >/dev/null 2>&1
for p in psoe pp sumar podemos salf adelante alianca custom regional; do
  "$GODOT" --headless --path . --script res://tests/sim_full_game.gd -- "$p" 2>&1 | grep -E "FAIL|Fallos" ; done
"$GODOT" --headless --path . --script res://tests/executive.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/macro.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/trust.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/cabinet.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/world.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/roles.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/negotiation.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/negotiation_ai.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/law_deals.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/history.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/diplomacy.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/parliament.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/table.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/irpf.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/manifesto.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/legislature.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/territory.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/party_roster.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/wizard.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/ideology.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/migrate_v2.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/media_db.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/encounters.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/encounters_match.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/electorate.gd 2>&1 | grep -E "FAIL|Fallos"
"$GODOT" --headless --path . --script res://tests/militancy.gd 2>&1 | grep -E "FAIL|Fallos"
if command -v xvfb-run >/dev/null; then
  xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 --script res://tests/pause_menu.gd 2>&1 | grep -E "FAIL|Fallos|SCRIPT ERROR"
  xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 --script res://tests/media_shots.gd -- psoe /tmp/media_run 2>&1 | grep -E "FALLO|SCRIPT ERROR|Capturas"
  for p in psoe custom regional; do
    xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 --script res://tests/ui_flow.gd -- "$p" 2>&1 | grep -E "SCRIPT ERROR|Fases"
  done
fi
exit $fail
