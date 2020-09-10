#!/bin/bash

DELAY=60
SUSPEND=$((60 * 15))
FREQ_CHANGE=false

params () {
    case "$1" in
        -s) USER=$(whoami)
            PIDGN=$(pgrep -u $USER gnome-session)
            export DBUS_SESSION_BUS_ADDRESS=$(\
                grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PIDGN/environ | \
                tr -d '\0' | cut -d= -f2-)
            $0 &
            sleep 3
            systemctl suspend -i
            exit;;
        -q) exec 2>/dev/null;;
        -f) FREQ_CHANGE=true;;
        -ws) SUSPEND=$((60 * 43200));;
        * ) echo "$1 is not an option"
            exit;;
    esac
}

for i in "$@"
do
    params $i
done

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCREEN="/tmp/screen.png"
tSCREEN="/tmp/screencrop.png"
BRGHT=$(cat /sys/class/backlight/intel_backlight/brightness)
LIMIT=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
CURFREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
NUMCORE=$(cat /sys/devices/system/cpu/online)
MAXFREQ=$(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq)
MINFREQ=$(cat /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_min_freq)

let "MIDFREQ = MAXFREQ / 2"

if [ "$LIMIT" -lt "$MIDFREQ" ]; then
    let "STEP = BRGHT / 40"
else
    let "STEP = BRGHT / 20"
fi

brghtdn () {
    if [ -w /sys/class/backlight/intel_backlight/brightness ]; then
        tBRGHT=$(cat /sys/class/backlight/intel_backlight/brightness)
        for ((i = $tBRGHT; i >= 47; i = i - $STEP)); do
            echo $i > /sys/class/backlight/intel_backlight/brightness
            sleep 0.02
        done
        sleep 0.02
    else
        echo dont have write permission for bright or file not found
    fi
}

brghtup () {
    if [ -w /sys/class/backlight/intel_backlight/brightness ]; then
        tBRGHT=$(cat /sys/class/backlight/intel_backlight/brightness)
        for ((i = $tBRGHT; i <= $BRGHT; i = i + $STEP)); do
            echo $i > /sys/class/backlight/intel_backlight/brightness
            sleep 0.01
        done
    else
        echo dont have write permission for bright or file not found
    fi
}

cpufreq () {
    if [ "$FREQ_CHANGE" = true  ] ; then
        if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ]; then
            if [ "$LIMIT" -ne "$MAXFREQ" ]; then
                for x in /sys/devices/system/cpu/cpu[$NUMCORE]/cpufreq/;do
                    echo $MAXFREQ > $x/scaling_max_freq
                done
                sleep 0.01
            fi
            for x in /sys/devices/system/cpu/cpu[$NUMCORE]/cpufreq/;do
                echo $1 > $x/scaling_max_freq
            done
        else
            echo dont have write permission for cpufreq or file not found
        fi
    fi
}

# scrot /tmp/screen.png
# ~/Downloads/xwobf-master/xwobf -s 5 /tmp/screen.png
# convert /tmp/screen.png -blur 0x3 /tmp/screen.png
# mogrify -scale 10% -scale 1000% -gamma 0.8 /tmp/screen.png
if xkb-switch --list &> /dev/null; then
    xkb-switch -s us
else
    setxkbmap "us" ",winkeys" "grp:alt_shift_toggle" "ctrl:nocaps"
    sleep 1
    setxkbmap "us,ru" ",winkeys" "grp:alt_shift_toggle" "ctrl:nocaps"
    (gsettings set org.gnome.desktop.input-sources current 0) &
fi
playerctl pause
# dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
    # /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause >> /dev/null
brghtdn &
# ~/Dropbox/linux/scrot /tmp/screen.png --blur 5 --icon ~/Dropbox/linux/lock.png
# (i3lock -n -i /tmp/screen.png && rm /tmp/screen.png && pkill -P $$) &
$DIR/scrot $SCREEN --blur 5

cp $SCREEN $tSCREEN
mogrify -gravity center -crop 250x250+0 +repage $tSCREEN
AVGCOLOR=$(convert $tSCREEN -scale 1x1\! \
    -format '%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]' info:- | \
    sed 's/,/\n/g' | \
    xargs -L 1 printf "%x")
INVCOLOR=$(printf "%06X\n" $((0xffffff-0x$AVGCOLOR)))

# ($DIR/i3lock -n --24 -e -i $SCREEN -w '#E08122' -o '#8AE234' -l '#34E2E2' \
($DIR/i3lock -n --24 -e -i $SCREEN -w ED3939 -o 8AE234 -l $INVCOLOR \
    && brghtup \
    && cpufreq $LIMIT \
    && rm $SCREEN \
    && rm $tSCREEN \
    && kill -9 $$) &
    # && pkill -P $$) &

if [ "$LIMIT" -ne "$MINFREQ" ]; then
    cpufreq $MINFREQ
fi

let "DELAY = DELAY / 2"
sspnd=$SUSPEND
while [[ $(pgrep i3lock) ]]; do
    brghtdn
    sleep $DELAY
    xset dpms force off
    while [[ "$(xset -q | sed -ne 's/^[ ]*Monitor is //p')" = "Off" ]]; do
        if [ $sspnd -le 0 ]; then
            sspnd=$SUSPEND
            systemctl suspend -i
        fi
        sleep 1
        sspnd=$((sspnd - 1))
    done
    brghtup
    sleep $DELAY
done

