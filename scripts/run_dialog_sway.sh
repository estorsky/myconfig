#!/bin/bash

rofi -show combi &

swaymsg input "1:1:AT_Translated_Set_2_keyboard" xkb_switch_layout 0
