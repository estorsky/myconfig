#!/bin/sh

cd pp4x/apps

make cli_new
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "cli_new make faild"
    exit $retVal
fi

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

