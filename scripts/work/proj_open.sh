#!/bin/bash

if [ $# -lt 1 ]; then
    echo "pls enter first arg - project, second - name tmux session"
    exit
fi

case "$1" in
    ltp-x|ltpx|x) PROJECT_NAME="ltp-x";;
    MA4000_1|m1) PROJECT_NAME="MA4000_1";;
    MA4000_2|m2) PROJECT_NAME="MA4000_2";;
    MA4000_3|m3) PROJECT_NAME="MA4000_3";;
    ltp-n_1|ltpn1|n1) PROJECT_NAME="ltp-n_1";;
    ltp-n_2|ltpn2|n2) PROJECT_NAME="ltp-n_2";;
    ltp-n_3|ltpn3|n3) PROJECT_NAME="ltp-n_3";;
    * ) echo "dont know project '$1'"
        exit;;
esac

cd ~/projects/$PROJECT_NAME
if [ $? -ne 0 ]; then
    echo "project dir not found"
    exit 1
fi

if [ -z "$2" ]; then
    SESSION_NAME="[$(echo "$PROJECT_NAME" | tr a-z A-Z)]"
else
    SESSION_NAME="[$(echo "$PROJECT_NAME" | tr a-z A-Z)] $2"
fi

if [[ -n $SSH_CONNECTION ]]; then
    SESSION_NAME="SSH $SESSION_NAME"
fi

tmux has-session -t "$SESSION_NAME" 2> /dev/null
test $? -eq 0 && tmux attach -t "$SESSION_NAME" && exit

tmux new-session -s "$SESSION_NAME" -n src -d
tmux send-keys -t "$SESSION_NAME" " sleep 1 && nvim" C-m C-n F8

tmux new-window -t "$SESSION_NAME" -n build
tmux send-keys -t "$SESSION_NAME" " dockerun.sh $1" C-m
tmux split-window -h -t "$SESSION_NAME"
tmux send-keys -t "$SESSION_NAME" " sleep 1 && ranger" C-m
if [[ "$PROJECT_NAME" == "MA4000_1" || "$PROJECT_NAME" == "MA4000_2" ]]; then
    tmux split-window -v -t "$SESSION_NAME"
    tmux send-keys -t "$SESSION_NAME" " cd ~/myconfig/scripts/work/ma/ && \
        clear && sleep 1 && nvim * +'tab all'" C-m C-n
# else
    # tmux split-window -v -t "$SESSION_NAME"
    # tmux send-keys -t "$SESSION_NAME" "cd ~/projects/$PROJECT_NAME && \
        # clear && sleep 1 && nvim *.sh +'tab all'" C-m C-n
fi

tmux new-window -t "$SESSION_NAME"
tmux split-window -h -t "$SESSION_NAME"

tmux select-window -t "$SESSION_NAME":1

tmux attach -t "$SESSION_NAME"

