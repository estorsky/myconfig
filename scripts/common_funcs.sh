if [ "$MY_ECHO" = true ]
then
    echo () {
        builtin echo " <> $(basename $0) ($(date '+%H:%M:%S')): $@"
    }
fi

myecho () {
    echo " <> $(basename $0) ($(date '+%H:%M:%S')): $@"
}

notif () {
    if [[ -z "$1" ]]
    then
        echo "notif() not enough arguments"
        exit 1
    fi

    if [[ -n $SSH_CONNECTION ]]; then
        dunstify () { true; }
    fi

    # env echo -en '\a'

    dunstify -u normal -t 10000 "$(basename $0)" "$1"
    nohup bash -c "tmux set message-style fg=colour237,bg=$TMUX_MAIN_COLOUR,bold && tmux display-message -d 2000 ' $1'" >/dev/null 2>&1 &
    echo "$1"
}

notif_check () {
    if [[ -z "$1" || -z "$2" || -z "$3" ]]
    then
        echo "notif_check() not enough arguments"
        exit 1
    fi

    if [[ -n $SSH_CONNECTION ]]; then
        dunstify () { true; }
    fi

    env echo -en '\a'

    if [ $1 -eq 0 ]; then
        dunstify -u normal "$(basename $0)" "$2"
        nohup bash -c "tmux display-message -d 2000 ' $2'" >/dev/null 2>&1 &
        echo "$2"
    elif [ $1 -eq 130 ]; then
        echo "command canceled"
        exit $1
    else
        dunstify -u critical "$(basename $0)" "$3"
        nohup bash -c "tmux set message-style fg=colour237,bg=colour203,bold && tmux display-message -d 2000 ' $3' && sleep 3 && tmux set message-style fg=colour237,bg=$TMUX_MAIN_COLOUR,bold" >/dev/null 2>&1 &
        echo "$3"
        exit 2
    fi
}

check_git () {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "directory '$(basename $(pwd))' is not a git repository"
        exit
    fi
}

check_connection () {
    set +e
    echo -n "Checking internet connection..."
    wget -q --spider http://google.com
    if [ $? -ne 0 ]; then
        echo "off"
        exit
    else
        echo "on"
    fi
}

run_with_root () {
    if [[ $(id -u) -ne 0 ]]; then
        sudo $0 $@
        exit
    fi
}

gclonecd() {
  git clone "$1" && cd "$(basename "$1" .git)"
}

