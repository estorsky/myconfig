SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# WORK
if [ -d ~/work ]; then
    source $SCRIPT_DIR/work/work_common_envs.sh
fi

