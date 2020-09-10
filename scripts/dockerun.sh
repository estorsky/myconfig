#!/bin/bash

ltpx () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/$USER/projects/toolchains/:/opt/toolchains \
        -v /home/$USER/projects:/home/user/projects \
        -v /home/$USER/tftp:/home/user/tftp \
        -w /home/user/projects/$PNAME \
        xpon/builder:latest \
        bash
}

ma4000 () {
    ltpx
}

ltpn () {
    docker run -t -i --rm --privileged \
        -v ~/.ssh/:/home/user/.ssh \
        -v /home/$USER/projects/$PNAME:/home/user/projects \
        -w /home/user/projects \
        xpon-ng.eltex.loc:5000/builders/ltp-n:latest \
        bash
}


params () {
    case "$1" in
        ltp-x|ltpx|x) PNAME="ltp-x"; ltpx
            exit;;
        ma4000|ma4k|ma|m) PNAME="MA4000"; ma4000
            exit;;
        ltp-n_1|ltpn1|n1) PNAME="ltp-n_1"; ltpn
            exit;;
        ltp-n_2|ltpn2|n2) PNAME="ltp-n_2"; ltpn
            exit;;
        ltp-n_3|ltpn3|n3) PNAME="ltp-n_3"; ltpn
            exit;;
        * ) echo "$1 is not an option"
            exit;;
    esac
}

for i in "$@"
do
    params $i
done

echo "select docker: ltpx, ma4000, ltpn."

