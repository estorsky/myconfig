#!/bin/bash

if [ "$(nmcli radio wifi)" = enabled ]
then
    nmcli radio all off
else
    nmcli radio all on
fi
