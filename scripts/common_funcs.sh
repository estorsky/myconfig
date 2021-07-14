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
    if [[ -z "$1" || -z "$2" || -z "$3" ]]
    then
        echo "notif() not enough arguments"
        exit 1
    fi

    if [[ -n $SSH_CONNECTION ]]; then
        dunstify () { true; }
    fi

    if [ $1 -eq 0 ]; then
        dunstify -u normal -t 10000 "$(basename $0)" "$2"
        echo "$2"
    else
        dunstify -u critical -t 10000 "$(basename $0)" "$3"
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

