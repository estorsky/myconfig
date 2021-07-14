#!/bin/bash

PROJECT_NAME="ltp-n_1"
CMD="bash"

build_ma4000=false
build_ltpx=false
build_ltpn=false

ma4000 () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/$USER/projects/toolchains/:/opt/toolchains \
        -v /home/$USER/projects:/home/user/projects \
        -v /home/$USER/shared:/home/user/shared \
        -v /home/$USER/myconfig/scripts/work/ma/:/home/user/projects/$PROJECT_NAME/scripts \
        -w /home/user/projects/$PROJECT_NAME \
        xpon/builder:latest \
        $CMD
}

ltpx () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/$USER/projects/toolchains/:/opt/toolchains \
        -v /home/$USER/projects:/home/user/projects \
        -v /home/$USER/shared:/home/user/shared \
        -w /home/user/projects/$PROJECT_NAME \
        xpon/builder:latest \
        $CMD
}

ltpn () {
    docker run -t -i --rm --privileged \
        -v ~/.gitconfig:/home/user/.gitconfig \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/$USER/projects/$PROJECT_NAME:/home/user/projects \
        -w /home/user/projects \
        xpon-ng.eltex.loc:5000/builders/ltp-n:latest \
        $CMD
}


POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        ltp-x|ltpx|x)
            PROJECT_NAME="ltp-x"
            build_ltpx=true
            shift
            ;;
        MA4000_1|m1)
            PROJECT_NAME="MA4000_1"
            build_ma4000=true
            shift
            ;;
        MA4000_2|m2)
            PROJECT_NAME="MA4000_2"
            build_ma4000=true
            shift
            ;;
        MA4000_3|m3)
            PROJECT_NAME="MA4000_3"
            build_ma4000=true
            shift
            ;;
        ltp-n_1|ltpn1|n1)
            PROJECT_NAME="ltp-n_1"
            build_ltpn=true
            shift
            ;;
        ltp-n_2|ltpn2|n2)
            PROJECT_NAME="ltp-n_2"
            build_ltpn=true
            shift
            ;;
        ltp-n_3|ltpn3|n3)
            PROJECT_NAME="ltp-n_3"
            build_ltpn=true
            shift
            ;;
        -c)
            CMD="$2"
            shift # past argument
            shift # past value
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


if [ "$build_ltpn" = true ]
then
    ltpn
    exit
elif [ "$build_ltpx" = true ]
then
    ltpx
    exit
elif [ "$build_ma4000" = true ]
then
    ma4000
    exit
fi

echo "select docker: ltpx, ma4000, ltpn."

