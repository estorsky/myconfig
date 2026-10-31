# shellcheck shell=bash
# Sourced by myconfig scripts. Sets MYCONFIG_SOCKS_HOST/MYCONFIG_SOCKS_PORT from
# dotfiles/proxy.env unless the port is already set in the environment.

_myconfig_proxy_env_file="${MYCONFIG_PROXY_ENV_FILE:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../dotfiles/proxy.env}"
if [[ -z "${MYCONFIG_SOCKS_PORT:-}" && -f "$_myconfig_proxy_env_file" ]]; then
    # shellcheck disable=SC1090
    . "$_myconfig_proxy_env_file"
fi
unset _myconfig_proxy_env_file

MYCONFIG_SOCKS_HOST="${MYCONFIG_SOCKS_HOST:-127.0.0.1}"
MYCONFIG_SOCKS_PORT="${MYCONFIG_SOCKS_PORT:-12334}"
