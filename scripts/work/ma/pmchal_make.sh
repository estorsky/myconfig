#!/bin/sh

cd plc/

rm -rf patched

./make.sh
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "plc make faild"
    # notify-send
    exit $retVal
fi

cd ../pp4x/initrd/
./fastmkcontainer.sh plc

LASTCRF=$(ls -t | head -1)
echo $LASTCRF
echo $HOME
rm -f $HOME/shared/firmware.ma4k
cp $LASTCRF $HOME/shared/firmware.ma4k

