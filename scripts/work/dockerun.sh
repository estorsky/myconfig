#!/bin/bash
# set -x

PROJECT_NAME="ltp-n_1"
CMD="bash"

build_ma4000=false
build_ltpx=false
build_ltpn=false
build_iss=false

ma4000 () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/"${USER}"/projects:/home/user/projects \
        -v /home/"${USER}"/shared:/home/user/shared \
        -v /home/"${USER}"/myconfig/scripts/work/ma/:/home/user/projects/$PROJECT_NAME/scripts \
        -w /home/user/projects/$PROJECT_NAME \
        xpon-ng.eltex.loc:5000/builders/ltp-x:latest \
        $CMD
        # -v /home/$USER/projects/toolchains/:/opt/toolchains \
}

ltpx () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/"${USER}"/projects:/home/user/projects \
        -v /home/"${USER}"/shared:/home/user/shared \
        -w /home/user/projects/$PROJECT_NAME \
        xpon-ng.eltex.loc:5000/builders/ltp-x:latest \
        $CMD
        # -v /home/$USER/projects/toolchains/:/opt/toolchains \
}

ltpn () {
    docker run -t -i --rm --privileged \
        -v ~/.gitconfig:/home/user/.gitconfig \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/"${USER}"/projects/realtek_iss:/home/user/projects \
        -w /home/user/projects \
        xpon-ng.eltex.loc:5000/builders/ltp-n:latest \
        $CMD
}

iss () {
    docker run -t -i --rm --privileged \
        -v /home/"${USER}"/projects/$PROJECT_NAME:/home/user/projects \
        -v ${PROJECT_NAME}_opt:/opt \
        -w /home/user/projects \
        gitlab.eltex.loc:4567/ethernet-switches/realtek_iss/builder:18.04 \
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
        ltp-x_2|ltpx2|x2)
            PROJECT_NAME="ltp-x_2"
            build_ltpx=true
            shift
            ;;
        MA4000_1|m1|ma|m)
            PROJECT_NAME="MA4000_1"
            build_ma4000=true
            shift
            ;;
        MA4000_2|m2)
            PROJECT_NAME="MA4000_2"
            build_ma4000=true
            shift
            ;;
        ltp-n_1|ltpn1|n1|n)
            PROJECT_NAME="ltp-n_1"
            build_ltpn=true
            shift
            ;;
        realtek_iss|iss|i)
            PROJECT_NAME="realtek_iss"
            build_iss=true
            shift
            ;;
        realtek_iss_2|iss2|i2)
            PROJECT_NAME="realtek_iss_2"
            build_iss=true
            shift
            ;;
        realtek_iss_3|iss3|i3)
            PROJECT_NAME="realtek_iss_3"
            build_iss=true
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
elif [ "$build_iss" = true ]
then
    iss
    exit
fi

echo "select docker: ltpx, ma4000, ltpn, iss."

