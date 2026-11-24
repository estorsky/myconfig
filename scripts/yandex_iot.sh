#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

# https://yandex.ru/dev/dialogs/smart-home/doc/ru/concepts/platform-quickstart
# https://yandex.ru/dev/id/doc/ru/tokens/debug-token

API_BASE="https://api.iot.yandex.net/v1.0"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/yandex-iot"

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "нужна команда '$1' (установите пакет и повторите)"
}

load_token() {
  local token="${YANDEX_IOT_TOKEN:-}"
  local token_file="${YANDEX_IOT_TOKEN_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/yandex-iot/token}"

  if [[ -z "${token}" && -f "${token_file}" ]]; then
    token="$(<"${token_file}")"
  fi

  token="${token//$'\r'/}"
  token="${token//$'\n'/}"

  [[ -n "${token}" ]] || die "не задан OAuth токен. Установите YANDEX_IOT_TOKEN или положите токен в '${token_file}'"
  echo "${token}"
}

CURL_OPTS=(-fsS --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 --retry-all-errors)

api_get() {
  local token="$1"
  local path="$2"
  curl "${CURL_OPTS[@]}" "${API_BASE}${path}" \
    -H "Authorization: Bearer ${token}" \
    || die "запрос к API не удался: GET ${path}"
}

api_post_json() {
  local token="$1"
  local path="$2"
  local json="$3"
  curl "${CURL_OPTS[@]}" "${API_BASE}${path}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    --data-raw "${json}" \
    || die "запрос к API не удался: POST ${path}"
}

print_usage() {
  cat <<'EOF'
Использование:
  yandex_iot.sh list                      устройства: имя, id, тип, комната
  yandex_iot.sh groups                    группы: имя, id, тип, комнаты, устройства
  yandex_iot.sh scenarios                 сценарии: имя, id, активен ли
  yandex_iot.sh status     ЦЕЛЬ
  yandex_iot.sh on         ЦЕЛЬ
  yandex_iot.sh off        ЦЕЛЬ
  yandex_iot.sh brightness ЦЕЛЬ ПРОЦЕНТ   1..100
  yandex_iot.sh temp       ЦЕЛЬ КЕЛЬВИНЫ  цветовая температура, например 2700..6500
  yandex_iot.sh scenario   (--id SCENARIO_ID | --name "Имя сценария")
  yandex_iot.sh dawn       ЦЕЛЬ [--minutes 15] [--detach]

ЦЕЛЬ:
  --id DEVICE_ID | --name "Имя устройства" [--room "Комната"] | --group "Имя или id группы"

dawn — рассвет: включает свет на 1% тёплым (2700 K) и за --minutes минут
плавно доводит до 100% и 6500 K. Останавливается, если свет выключили.
--detach — уйти в фон и сразу вернуть управление (лог: ~/.local/state/yandex-iot/dawn.log).

Токен:
  export YANDEX_IOT_TOKEN="..."
  # либо файл (по умолчанию):
  ~/.config/yandex-iot/token
  # либо:
  export YANDEX_IOT_TOKEN_FILE="/path/to/token"

Примеры:
  yandex_iot.sh list
  yandex_iot.sh off --name "Розетка на столе"
  yandex_iot.sh status --id "socket-abc123"
  yandex_iot.sh brightness --name "Люстра" --room "Кухня" 40
  yandex_iot.sh dawn --group "Люстра" --minutes 15 --detach
  yandex_iot.sh scenario --name "Доброе утро"
EOF
}

# Печатает "<kind>\t<id>", где kind — device или group.
resolve_target() {
  local token="$1" id="$2" name="$3" room="$4" group="$5"
  local info matches count

  if [[ -n "${id}" ]]; then
    printf 'device\t%s\n' "${id}"
    return
  fi

  info="$(api_get "${token}" "/user/info")"

  if [[ -n "${group}" ]]; then
    matches="$(
      echo "${info}" | jq -r --arg q "${group}" '
        .groups[] | select(.id==$q or .name==$q or ((.aliases // []) | index($q))) | .id
      '
    )"
    [[ -n "${matches}" ]] || die "группа '${group}' не найдена (смотрите 'yandex_iot.sh groups')"
    count="$(echo "${matches}" | wc -l | tr -d ' ')"
    [[ "${count}" == "1" ]] || die "несколько групп '${group}', укажите id: $(echo "${matches}" | tr '\n' ' ')"
    printf 'group\t%s\n' "${matches}"
    return
  fi

  [[ -n "${name}" ]] || die "нужно указать --id, --name или --group"

  matches="$(
    echo "${info}" | jq -r --arg q "${name}" --arg room "${room}" '
      ((.rooms // []) | map({(.id): .name}) | add // {}) as $rooms
      | .devices[]
      | select(.name==$q or ((.aliases // []) | index($q)))
      | select($room == "" or $rooms[.room // ""] == $room)
      | [.id, .name, .type, ($rooms[.room // ""] // "")] | @tsv
    '
  )"

  if [[ -z "${matches}" ]]; then
    die "устройство '${name}'${room:+ в комнате '${room}'} не найдено (смотрите 'yandex_iot.sh list')"
  fi

  count="$(echo "${matches}" | wc -l | tr -d ' ')"
  if [[ "${count}" != "1" ]]; then
    echo "Найдено несколько устройств для '${name}'. Уточните через --room или --id:" >&2
    echo "${matches}" | awk -F'\t' '{printf "  id=%s  name=%s  type=%s  room=%s\n",$1,$2,$3,$4}' >&2
    exit 3
  fi

  printf 'device\t%s\n' "$(echo "${matches}" | awk -F'\t' '{print $1}')"
}

# actions — JSON-массив действий для одной цели.
send_actions() {
  local token="$1" kind="$2" id="$3" actions="$4"
  local resp request_id result

  if [[ "${kind}" == "group" ]]; then
    resp="$(api_post_json "${token}" "/groups/${id}/actions" "$(jq -nc --argjson a "${actions}" '{actions: $a}')")"
    request_id="$(echo "${resp}" | jq -r '.request_id // empty')"
    result="$(echo "${resp}" | jq -r '.status // empty')"
  else
    resp="$(api_post_json "${token}" "/devices/actions" "$(jq -nc --arg id "${id}" --argjson a "${actions}" '{devices: [{id: $id, actions: $a}]}')")"
    request_id="$(echo "${resp}" | jq -r '.request_id // empty')"
    result="$(echo "${resp}" | jq -r '[.devices[0].capabilities[].state.action_result.status] | unique | join(",")')"
  fi

  [[ -n "${result}" ]] || die "неожиданный ответ API (request_id=${request_id:-n/a}): ${resp}"
  echo "request_id=${request_id:-n/a} result=${result}"
}

act_on_off() {
  jq -nc --argjson v "$1" '[{type: "devices.capabilities.on_off", state: {instance: "on", value: $v}}]'
}

act_light() {
  local brightness="$1" temp="${2:-}"
  jq -nc --argjson b "${brightness}" --arg t "${temp}" '
    [{type: "devices.capabilities.on_off", state: {instance: "on", value: true}},
     {type: "devices.capabilities.range", state: {instance: "brightness", value: $b}}]
    + (if $t == "" then [] else
        [{type: "devices.capabilities.color_setting", state: {instance: "temperature_k", value: ($t | tonumber)}}]
      end)
  '
}

# Печатает true, false или unknown (API недоступен).
target_on_state() {
  local token="$1" kind="$2" id="$3"
  local path="/devices/${id}" resp
  [[ "${kind}" == "group" ]] && path="/groups/${id}"
  if ! resp="$(curl -fsS --max-time 5 "${API_BASE}${path}" -H "Authorization: Bearer ${token}" 2>/dev/null)"; then
    echo unknown
    return
  fi
  echo "${resp}" | jq -r '
    [(.capabilities // [])[] | select(.type=="devices.capabilities.on_off") | .state.value][0] // "unknown"
  '
}

cmd_list() {
  local token="$1"
  api_get "${token}" "/user/info" | jq -r '
    ((.rooms // []) | map({(.id): .name}) | add // {}) as $rooms
    | .devices[]
    | [
        (.name // ""),
        (.id // ""),
        (.type // ""),
        ($rooms[.room // ""] // "")
      ]
    | @tsv
  ' | awk -F'\t' '{printf "%-32s  %-36s  %-44s  %s\n",$1,$2,$3,$4}'
}

cmd_groups() {
  local token="$1"
  api_get "${token}" "/user/info" | jq -r '
    ((.rooms // []) | map({(.id): .name}) | add // {}) as $rooms
    | (.devices | map({(.id): .}) | add // {}) as $devs
    | .groups[]
    | [
        .name,
        .id,
        (.type // ""),
        ([.devices[] | $rooms[$devs[.].room // ""] // empty] | unique | join(",")),
        ([.devices[] | $devs[.].name // .] | join(", "))
      ]
    | @tsv
  ' | awk -F'\t' '{printf "%-28s  %-36s  %-30s  %-16s  %s\n",$1,$2,$3,$4,$5}'
}

cmd_scenarios() {
  local token="$1"
  api_get "${token}" "/user/info" | jq -r '
    .scenarios[] | [.name, .id, (if .is_active then "active" else "inactive" end)] | @tsv
  ' | awk -F'\t' '{printf "%-48s  %-36s  %s\n",$1,$2,$3}'
}

cmd_status() {
  local token="$1" kind="$2" id="$3"
  local path="/devices/${id}"
  [[ "${kind}" == "group" ]] && path="/groups/${id}"
  api_get "${token}" "${path}" | jq -r --arg kind "${kind}" '
    . as $d
    | ($d.capabilities // []) as $caps
    | ($caps | map(select(.type=="devices.capabilities.on_off"))[0].state.value) as $on
    | ($caps | map(select(.state.instance=="brightness"))[0].state.value) as $br
    | ($caps | map(select(.state.instance=="temperature_k"))[0].state.value) as $tk
    | "\($kind) name=\($d.name) id=\($d.id) online=\($d.state) on=\($on)"
      + (if $br then " brightness=\($br)" else "" end)
      + (if $tk then " temperature_k=\($tk)" else "" end)
  '
}

cmd_scenario() {
  local token="$1" id="$2" name="$3"
  local matches resp

  if [[ -z "${id}" ]]; then
    [[ -n "${name}" ]] || die "нужно указать --id или --name сценария"
    matches="$(api_get "${token}" "/user/info" | jq -r --arg q "${name}" '.scenarios[] | select(.name==$q) | .id')"
    [[ -n "${matches}" ]] || die "сценарий '${name}' не найден (смотрите 'yandex_iot.sh scenarios')"
    [[ "$(echo "${matches}" | wc -l | tr -d ' ')" == "1" ]] || die "несколько сценариев '${name}', укажите --id"
    id="${matches}"
  fi

  resp="$(api_post_json "${token}" "/scenarios/${id}/actions" "")"
  echo "${resp}" | jq -r '"request_id=\(.request_id // "n/a") result=\(.status // "unknown")"'
}

cmd_dawn() {
  local token="$1" kind="$2" id="$3" minutes="$4"
  local steps=30 t_from=2700 t_to=6500
  local total start i e b t wait

  [[ "${minutes}" =~ ^[0-9]+$ && "${minutes}" -ge 1 ]] || die "--minutes: целое число минут ≥ 1"
  total=$(( minutes * 60 ))

  echo "$(date '+%F %T') dawn start ${kind}=${id} minutes=${minutes}"
  send_actions "${token}" "${kind}" "${id}" "$(act_light 1 "${t_from}")"
  start=$(date +%s)

  # Шаги привязаны к часам: медленный API пропускает шаги, но не растягивает рассвет.
  for (( i = 1; i <= steps; i++ )); do
    wait=$(( start + total * i / steps - $(date +%s) ))
    if (( wait > 0 )); then
      sleep "${wait}"
    elif (( i < steps )); then
      continue
    fi
    case "$(target_on_state "${token}" "${kind}" "${id}")" in
      false)
        echo "$(date '+%F %T') dawn stopped: свет выключен"
        return 0
        ;;
      unknown) echo "$(date '+%F %T') step ${i}: состояние не получено, продолжаю" ;;
    esac
    e=$(( $(date +%s) - start ))
    (( e <= total )) || e=${total}
    # Яркость по квадрату времени: глазу рост кажется равномерным.
    b=$(( 1 + 99 * e * e / (total * total) ))
    t=$(( (t_from + (t_to - t_from) * e / total) / 100 * 100 ))
    ( send_actions "${token}" "${kind}" "${id}" "$(act_light "${b}" "${t}")" ) >/dev/null \
      || echo "$(date '+%F %T') step ${i}: ошибка API, продолжаю"
  done

  if ( send_actions "${token}" "${kind}" "${id}" "$(act_light 100 "${t_to}")" ) >/dev/null; then
    echo "$(date '+%F %T') dawn done"
  else
    echo "$(date '+%F %T') dawn done, но финальные 100% не выставлены: ошибка API"
  fi
}

main() {
  need_cmd curl
  need_cmd jq

  local cmd="${1:-}"
  shift || true

  if [[ -z "${cmd}" || "${cmd}" == "-h" || "${cmd}" == "--help" ]]; then
    print_usage
    exit 0
  fi

  local token id="" name="" room="" group="" minutes=15 detach=0 value=""
  local -a orig_args=("$@")

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)      shift; id="${1:-}" ;;
      --name)    shift; name="${1:-}" ;;
      --room)    shift; room="${1:-}" ;;
      --group)   shift; group="${1:-}" ;;
      --minutes) shift; minutes="${1:-}" ;;
      --detach)  detach=1 ;;
      -*)        die "неизвестный аргумент: $1" ;;
      *)
        [[ -z "${value}" ]] || die "лишний аргумент: $1"
        value="$1"
        ;;
    esac
    shift || true
  done

  token="$(load_token)"

  local kind target
  case "${cmd}" in
    list)      cmd_list "${token}" ;;
    groups)    cmd_groups "${token}" ;;
    scenarios) cmd_scenarios "${token}" ;;
    scenario)  cmd_scenario "${token}" "${id}" "${name}" ;;
    status|on|off|brightness|temp|dawn)
      target="$(resolve_target "${token}" "${id}" "${name}" "${room}" "${group}")"
      kind="${target%%$'\t'*}"
      id="${target#*$'\t'}"

      case "${cmd}" in
        status) cmd_status "${token}" "${kind}" "${id}" ;;
        on)     send_actions "${token}" "${kind}" "${id}" "$(act_on_off true)" ;;
        off)    send_actions "${token}" "${kind}" "${id}" "$(act_on_off false)" ;;
        brightness)
          [[ "${value}" =~ ^[0-9]+$ && "${value}" -ge 1 && "${value}" -le 100 ]] || die "яркость: число 1..100"
          send_actions "${token}" "${kind}" "${id}" "$(act_light "${value}")"
          ;;
        temp)
          [[ "${value}" =~ ^[0-9]+$ ]] || die "температура: число в кельвинах, например 4500"
          send_actions "${token}" "${kind}" "${id}" \
            "$(jq -nc --argjson t "${value}" '[{type: "devices.capabilities.color_setting", state: {instance: "temperature_k", value: $t}}]')"
          ;;
        dawn)
          if (( detach )); then
            mkdir -p "${STATE_DIR}"
            local -a args=()
            local a
            for a in "${orig_args[@]}"; do [[ "${a}" == "--detach" ]] || args+=("${a}"); done
            setsid nohup "$(readlink -f "$0")" dawn "${args[@]}" >>"${STATE_DIR}/dawn.log" 2>&1 </dev/null &
            echo "dawn запущен в фоне (pid $!), лог: ${STATE_DIR}/dawn.log"
          else
            cmd_dawn "${token}" "${kind}" "${id}" "${minutes}"
          fi
          ;;
      esac
      ;;
    *)
      die "неизвестная команда: ${cmd} (см. --help)"
      ;;
  esac
}

main "$@"
