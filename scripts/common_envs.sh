SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

KEYBOARD="$(swaymsg -t get_inputs | jq -r '[.[] | select(.type == "keyboard") | select(.identifier | test("Keyboard"; "i")) | .identifier][0]')"

# WORK
if [ -d ~/work ]; then
    source $SCRIPT_DIR/work/work_common_envs.sh
fi

