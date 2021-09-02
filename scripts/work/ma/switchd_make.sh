#!/bin/sh

cd pp4x/apps

make switchd
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "switchd make faild"
    exit $retVal
fi

# make cli_new
# retVal=$?
# if [ $retVal -ne 0 ]; then
    # echo "Error"
    # exit $retVal
# fi

# make dhcp_relay
# retVal=$?
# if [ $retVal -ne 0 ]; then
    # echo "Error"
    # exit $retVal
# fi
# echo $PWD

cd ..
echo $PWD
make initrd

cd initrd
echo $PWD
./fastmkcontainer.sh plc

LASTCRF=$(ls -t | head -1)
echo $LASTCRF
echo $HOME
rm -f $HOME/shared/firmware.ma4k
cp $LASTCRF $HOME/shared/firmware.ma4k

