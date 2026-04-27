#!/bin/bash
#
# Управление DPMS для Sway с учётом внешних мониторов через хаб.
# Идея: "dpms off" на внешних (DP/HDMI) иногда приводит к зависанию/пропаже
# монитора и необходимости переподключать хаб. Поэтому гасим только eDP*.
#

set -euo pipefail

ACTION="${1:-}"
if [[ "$ACTION" != "on" && "$ACTION" != "off" ]]; then
    echo "Usage: $0 on|off" >&2
    exit 2
fi

if [[ "$ACTION" == "on" ]]; then
    # Иногда одного вызова не хватает: повторяем с небольшой паузой.
    swaymsg 'output * dpms on' >/dev/null 2>&1 || true
    sleep 0.2
    swaymsg 'output * dpms on' >/dev/null 2>&1 || true

    # Подтолкнём way-displays перечитать конфиг/outputs (без reload Sway).
    pkill -HUP way-displays 2>/dev/null || true
    exit 0
fi

# ACTION == off: гасим только встроенную матрицу (eDP*), если она активна.
PY_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PY_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PY_BIN="python"
fi

if [[ -z "$PY_BIN" ]]; then
    # Fallback без JSON-парсинга: best-effort только для eDP-1
    swaymsg 'output eDP-1 dpms off' >/dev/null 2>&1 || true
    exit 0
fi

EDP_OUTPUTS="$(
    swaymsg -t get_outputs -r 2>/dev/null | "$PY_BIN" -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for o in data:
    name = o.get("name", "")
    if o.get("active") and name.startswith("eDP"):
        print(name)
' || true
)"

if [[ -z "${EDP_OUTPUTS}" ]]; then
    exit 0
fi

while IFS= read -r out; do
    [[ -n "$out" ]] || continue
    swaymsg "output $out dpms off" >/dev/null 2>&1 || true
done <<< "${EDP_OUTPUTS}"

