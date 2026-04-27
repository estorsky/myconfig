#!/bin/bash
set -euo pipefail

# https://yandex.ru/dev/dialogs/smart-home/doc/ru/concepts/platform-quickstart
# https://yandex.ru/dev/id/doc/ru/tokens/debug-token

API_BASE="https://api.iot.yandex.net/v1.0"

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

api_get() {
  local token="$1"
  local path="$2"
  curl -fsS "${API_BASE}${path}" \
    -H "Authorization: Bearer ${token}"
}

api_post_json() {
  local token="$1"
  local path="$2"
  local json="$3"
  curl -fsS "${API_BASE}${path}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    --data-raw "${json}"
}

print_usage() {
  cat <<'EOF'
Использование:
  yandex_iot.sh list
  yandex_iot.sh status (--id DEVICE_ID | --name "Имя устройства")
  yandex_iot.sh on     (--id DEVICE_ID | --name "Имя устройства")
  yandex_iot.sh off    (--id DEVICE_ID | --name "Имя устройства")

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
EOF
}

find_device_id() {
  local token="$1"
  local query="$2"

  local info matches count
  info="$(api_get "${token}" "/user/info")"
  matches="$(
    echo "${info}" | jq -r --arg q "${query}" '
      .devices[]
      | select(.name==$q or ((.aliases // []) | index($q)))
      | [.id, .name, .type] | @tsv
    '
  )"

  if [[ -z "${matches}" ]]; then
    die "устройство с именем/алиасом '${query}' не найдено (смотрите 'yandex_iot.sh list')"
  fi

  count="$(echo "${matches}" | wc -l | tr -d ' ')"
  if [[ "${count}" != "1" ]]; then
    echo "Найдено несколько устройств для '${query}'. Уточните через --id:" >&2
    echo "${matches}" | awk -F'\t' '{printf "  id=%s  name=%s  type=%s\n",$1,$2,$3}' >&2
    exit 3
  fi

  echo "${matches}" | awk -F'\t' '{print $1}'
}

cmd_list() {
  local token="$1"
  api_get "${token}" "/user/info" | jq -r '
    .devices[]
    | [
        (.name // ""),
        (.id // ""),
        (.type // ""),
        (.room // "")
      ]
    | @tsv
  ' | awk -F'\t' '{printf "%-32s  %-28s  %-28s  %s\n",$1,$2,$3,$4}'
}

cmd_status() {
  local token="$1"
  local id="$2"
  api_get "${token}" "/devices/${id}" | jq -r '
    . as $d
    | ($d.capabilities // [])
    | map(select(.type=="devices.capabilities.on_off"))[0].state.value as $on
    | "name=\($d.name) id=\($d.id) online=\($d.state) on=\($on)"
  '
}

cmd_set_onoff() {
  local token="$1"
  local id="$2"
  local value="$3" # true/false

  local payload resp request_id result
  payload="$(
    jq -n --arg id "${id}" --argjson value "${value}" '
      {
        devices: [{
          id: $id,
          actions: [{
            type: "devices.capabilities.on_off",
            state: { instance: "on", value: $value }
          }]
        }]
      }
    '
  )"

  resp="$(api_post_json "${token}" "/devices/actions" "${payload}")"
  request_id="$(echo "${resp}" | jq -r '.request_id // empty')"
  result="$(echo "${resp}" | jq -r '.devices[0].capabilities[0].state.action_result.status // empty')"

  [[ -n "${result}" ]] || die "неожиданный ответ API (request_id=${request_id:-n/a}): ${resp}"
  echo "request_id=${request_id:-n/a} result=${result}"
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

  local token id name
  token="$(load_token)"

  case "${cmd}" in
    list)
      cmd_list "${token}"
      ;;
    status|on|off)
      id=""
      name=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --id)
            shift
            id="${1:-}"
            ;;
          --name)
            shift
            name="${1:-}"
            ;;
          *)
            die "неизвестный аргумент: $1"
            ;;
        esac
        shift || true
      done

      if [[ -z "${id}" ]]; then
        [[ -n "${name}" ]] || die "нужно указать --id или --name"
        id="$(find_device_id "${token}" "${name}")"
      fi

      case "${cmd}" in
        status) cmd_status "${token}" "${id}" ;;
        on)     cmd_set_onoff "${token}" "${id}" true ;;
        off)    cmd_set_onoff "${token}" "${id}" false ;;
      esac
      ;;
    *)
      die "неизвестная команда: ${cmd} (см. --help)"
      ;;
  esac
}

main "$@"
