#!/bin/bash
# Launch the Arduino PLC IDE under Wine on Linux, with working serial ports.
#
# Two things this handles that trip everyone up (see README.md):
#   1. Wine rewrites dosdevices/com* while it boots, so the port symlinks must be
#      created AFTER the Wine service is up, not before.
#   2. The device catalog fails to load unless Wine's HTML engine is disabled.
#
# COM1 = first serial interface of the board (if00)
# COM2 = second serial interface of the board (if02) -- usually the one to use
set -u

# --- Configuration -----------------------------------------------------------
# Override from the environment if your prefix lives elsewhere, e.g.
#   PLC_PREFIX=~/wine/plc  ./plc-ide.sh
PLC_PREFIX="${PLC_PREFIX:-$HOME/.local/share/arduino-plc-ide/wine}"
PLC_LOG="${PLC_LOG:-$HOME/.local/state/arduino-plc-ide.log}"

# Board to look for under /dev/serial/by-id/. The default matches an Arduino
# Opta; for a Portenta Machine Control adjust the pattern accordingly.
PLC_BOARD_GLOB="${PLC_BOARD_GLOB:-usb-Arduino_Arduino_Opta_*}"

IDE="$PLC_PREFIX/drive_c/Program Files (x86)/Arduino PLC IDE/Arduino PLC IDE/Arduino PLC IDE.exe"

export WINEPREFIX="$PLC_PREFIX"
export WINEDEBUG="${WINEDEBUG:--all}"
# mshtml=d is what makes the device catalog load; without it the IDE reports
# "Can not load device template ... Resources configuration will not be loaded".
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree=d;mshtml=d}"

mkdir -p "$(dirname "$PLC_LOG")"

note() {   # desktop notification if available, always to the log
    echo "$(date '+%F %T') $*" >> "$PLC_LOG"
    command -v notify-send >/dev/null && notify-send "Arduino PLC IDE" "$*"
}

[ -f "$IDE" ] || { note "IDE not found: $IDE"; exit 1; }

# Running twice would make both instances fight over the serial port.
if pgrep -f "Arduino PLC IDE.exe" >/dev/null 2>&1; then
    note "The IDE is already running."
    exit 0
fi

# --- Locate the board --------------------------------------------------------
# Via /dev/serial/by-id so the mapping survives reboots and replugging.
dd="$PLC_PREFIX/dosdevices"
if00=$(ls /dev/serial/by-id/${PLC_BOARD_GLOB}-if00 2>/dev/null | head -1)
if02=$(ls /dev/serial/by-id/${PLC_BOARD_GLOB}-if02 2>/dev/null | head -1)

[ -n "$if00" ] || note "No board found on USB - the IDE will start but find no device."

if [ -n "$if00" ] && [ ! -w "$if00" ]; then
    note "No write access to $if00 - are you in the 'dialout' group?"
fi

# --- Boot Wine FIRST, map the ports SECOND -----------------------------------
# This order is the whole point. While booting, Wine enumerates serial devices
# itself and overwrites dosdevices/com* with the built-in ports (/dev/ttyS0,
# /dev/ttyS1, ...). Map the ports before that and you silently lose the mapping:
# the IDE still lists COM1/COM2, but there is a dead port behind them and it
# reports "Unable to start the communication".
wineserver -k 2>/dev/null
sleep 1
wineserver -p                    # keep the service alive, or it boots again
wine wineboot >/dev/null 2>&1    # Wine writes its own COM mapping here

if [ -n "$if00" ]; then
    ln -sfn "$if00" "$dd/com1"
    [ -n "$if02" ] && ln -sfn "$if02" "$dd/com2"
    echo "$(date '+%F %T') COM1 -> $(readlink -f "$dd/com1") / COM2 -> $(readlink -f "$dd/com2")" >> "$PLC_LOG"
fi

cd "$(dirname "$IDE")" || exit 1
# An optional project path (Windows style, e.g. 'C:\projects\demo\demo.plcprj')
# is opened directly; without an argument the IDE starts empty.
exec wine "$IDE" "$@" >> "$PLC_LOG" 2>&1
