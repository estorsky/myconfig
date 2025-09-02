#!/bin/bash

MONITOR_1=$(swaymsg -t get_outputs | jq -r '.[] | select(.serial == "JCLMQS009609").name')
MONITOR_2=$(swaymsg -t get_outputs | jq -r '.[] | select(.serial == "KALMQS121524").name')

# TODO: fix pos
swaymsg output eDP-1 position 0 0 mode 2560x1440@144.000Hz
swaymsg output "${MONITOR_1}" position 2880 0 mode 1920x1080@60.000Hz
swaymsg output "${MONITOR_2}" position 4800 0 mode 1920x1080@60.000Hz
swaymsg output eDP-1 disable
swaymsg output "${MONITOR_1}" enable
swaymsg output "${MONITOR_2}" enable

# swaymsg '[workspace="1"]' move workspace to output "${MONITOR_1}"
# swaymsg '[workspace="2"]' move workspace to output "${MONITOR_1}"
# swaymsg '[workspace="3"]' move workspace to output "${MONITOR_1}"
# swaymsg '[workspace="4"]' move workspace to output "${MONITOR_1}"
# swaymsg '[workspace="5"]' move workspace to output "${MONITOR_1}"
# swaymsg '[workspace="6"]' move workspace to output "${MONITOR_2}"
# swaymsg '[workspace="7"]' move workspace to output "${MONITOR_2}"
# swaymsg '[workspace="8"]' move workspace to output "${MONITOR_2}"
# swaymsg '[workspace="9"]' move workspace to output "${MONITOR_2}"
# swaymsg '[workspace="10"]' move workspace to output "${MONITOR_2}"

# swaymsg "workspace 1 output ${MONITOR_1}"
# swaymsg "workspace 2 output ${MONITOR_1}"
# swaymsg "workspace 3 output ${MONITOR_1}"
# swaymsg "workspace 4 output ${MONITOR_1}"
# swaymsg "workspace 5 output ${MONITOR_1}"
# swaymsg "workspace 6 output ${MONITOR_2}"
# swaymsg "workspace 7 output ${MONITOR_2}"
# swaymsg "workspace 8 output ${MONITOR_2}"
# swaymsg "workspace 9 output ${MONITOR_2}"
# swaymsg "workspace 10 output ${MONITOR_2}"

# > swaymsg -t get_outputs
# Output DP-10 'Ancor Communications Inc ASUS VS229 KALMQS121524'
  # Current mode: 1920x1080 @ 60.000 Hz
  # Power: on
  # Position: 4800,0
  # Scale factor: 1.000000
  # Scale filter: nearest
  # Subpixel hinting: unknown
  # Transform: normal
  # Workspace: 4
  # Max render time: off
  # Adaptive sync: disabled
  # Allow tearing: no
  # Available modes:
    # 1920x1080 @ 60.000 Hz
    # 1600x1200 @ 60.000 Hz
    # 1680x1050 @ 59.883 Hz
    # 1280x1024 @ 75.025 Hz
    # 1280x1024 @ 60.020 Hz
    # 1440x900 @ 59.901 Hz
    # 1280x960 @ 60.000 Hz
    # 1152x864 @ 75.000 Hz
    # 1024x768 @ 75.029 Hz
    # 1024x768 @ 70.069 Hz
    # 1024x768 @ 60.004 Hz
    # 832x624 @ 74.551 Hz
    # 800x600 @ 75.000 Hz
    # 800x600 @ 72.188 Hz
    # 800x600 @ 60.317 Hz
    # 800x600 @ 56.250 Hz
    # 640x480 @ 75.000 Hz
    # 640x480 @ 72.809 Hz
    # 640x480 @ 66.667 Hz
    # 640x480 @ 59.940 Hz
    # 720x400 @ 70.082 Hz
#
# Output DP-9 'Ancor Communications Inc ASUS VS229 JCLMQS009609' (focused)
  # Current mode: 1920x1080 @ 60.000 Hz
  # Power: on
  # Position: 2880,0
  # Scale factor: 1.000000
  # Scale filter: nearest
  # Subpixel hinting: unknown
  # Transform: normal
  # Workspace: 5
  # Max render time: off
  # Adaptive sync: disabled
  # Allow tearing: no
  # Available modes:
    # 1920x1080 @ 60.000 Hz
    # 1600x1200 @ 60.000 Hz
    # 1680x1050 @ 59.883 Hz
    # 1280x1024 @ 75.025 Hz
    # 1280x1024 @ 60.020 Hz
    # 1440x900 @ 59.901 Hz
    # 1280x960 @ 60.000 Hz
    # 1152x864 @ 75.000 Hz
    # 1024x768 @ 75.029 Hz
    # 1024x768 @ 70.069 Hz
    # 1024x768 @ 60.004 Hz
    # 832x624 @ 74.551 Hz
    # 800x600 @ 75.000 Hz
    # 800x600 @ 72.188 Hz
    # 800x600 @ 60.317 Hz
    # 800x600 @ 56.250 Hz
    # 640x480 @ 75.000 Hz
    # 640x480 @ 72.809 Hz
    # 640x480 @ 66.667 Hz
    # 640x480 @ 59.940 Hz
    # 720x400 @ 70.082 Hz
#
# Output eDP-1 'Samsung Display Corp. ATNA40CU05-0  Unknown'
  # Current mode: 2880x1800 @ 120.000 Hz
  # Power: on
  # Position: 1440,0
  # Scale factor: 2.000000
  # Scale filter: nearest
  # Subpixel hinting: unknown
  # Transform: normal
  # Workspace: 6
  # Max render time: off
  # Adaptive sync: disabled
  # Allow tearing: no
  # Available modes:
    # 2880x1800 @ 120.000 Hz
    # 2880x1800 @ 60.001 Hz
    # 1920x1200 @ 120.000 Hz
    # 1920x1080 @ 120.000 Hz
    # 1600x1200 @ 120.000 Hz
    # 1680x1050 @ 120.000 Hz
    # 1280x1024 @ 120.000 Hz
    # 1440x900 @ 120.000 Hz
    # 1280x800 @ 120.000 Hz
    # 1280x720 @ 120.000 Hz
    # 1024x768 @ 120.000 Hz
    # 800x600 @ 120.000 Hz
    # 640x480 @ 120.000 Hz
