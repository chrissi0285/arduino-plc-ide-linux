# Arduino PLC IDE on Linux (Wine)

The Arduino PLC IDE is Windows-only. It runs under Wine — including a working
serial connection to an Arduino Opta — but two problems stop most people before
they get there. Both are documented here, with a launcher script that handles
them.

Verified on 2026-09-20 with Arduino PLC IDE 1.0.8, Wine 9.0 (32-bit prefix),
Linux Mint, and an Arduino Opta running PLC runtime 1.34.2.

*(Deutsche Fassung: [README.de.md](README.de.md))*

## Quick start

```bash
sudo usermod -a -G dialout "$USER"   # then log out and back in
sudo apt remove brltty               # hijacks Arduino boards on USB

export WINEPREFIX=~/.local/share/arduino-plc-ide/wine
export WINEARCH=win32
winetricks -q vcrun2019 msxml3 msxml6
wine /path/to/ArduinoPLCIDE_setup.exe

chmod +x plc-ide.sh
./plc-ide.sh                         # or: ./plc-ide.sh 'C:\projects\demo\demo.plcprj'
```

## Problem 1: Wine rewrites the COM mapping while it boots

Wine maps Windows ports (COM1, COM2, …) through symlinks in the prefix's
`dosdevices` directory. An Opta shows up on Linux as `/dev/ttyACM0` and
`/dev/ttyACM1`, which Wine assigns to high numbers such as COM35/COM36 — numbers
the IDE does not offer in its connection dialog.

The obvious fix — symlink the ports to low numbers before starting — **does not
work**. While booting, Wine enumerates the serial devices itself and overwrites
`dosdevices/com*` with the built-in ports (`/dev/ttyS0`, `/dev/ttyS1`, …). Map
them first and you lose the mapping again. The IDE then still lists COM1 and
COM2, but there is a dead port behind them, and connecting fails with:

```
Unable to start the communication
Choose 'On-line / Set up communication' to configure it
```

This is the trap that costs people hours, because everything *looks* right.

**Fix:** bring the Wine service up first, map the ports second.

```bash
wineserver -k          # stop running Wine processes
wineserver -p          # keep the service alive, or it boots again
wine wineboot          # Wine writes its own COM mapping here
ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<serial>-if00 "$WINEPREFIX/dosdevices/com1"
ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<serial>-if02 "$WINEPREFIX/dosdevices/com2"
wine ".../Arduino PLC IDE.exe"
```

Use `/dev/serial/by-id/` rather than `/dev/ttyACM*` so the mapping survives
reboots and replugging. `plc-ide.sh` does all of this in the right order and
finds the serial number on its own.

## Problem 2: "Can not load device template … from Catalog"

On startup the IDE reports:

```
Can not load device template 'LogicLab.pct' from Catalog!
Resources configuration will not be loaded.
```

The *Resources* section is then missing from the project tree — which is exactly
where the device and connection settings live.

**Fix:** disable Wine's HTML engine before launching:

```bash
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"
```

The catalog then loads and the project tree is complete. Note that the template
file itself is fine and Wine resolves its path correctly (including the
case mismatch between `Templates\` and `templates/`) — the failure is in
rendering, not in finding it.

## Finding the right port and settings — by measuring, not guessing

The board exposes two serial interfaces. Which one answers, and with which
parameters, can be measured before touching the GUI. `mbpoll` only reads and
changes nothing on the device:

```bash
mbpoll -m rtu -b 38400 -P none -d 8 -s 1 -a 247 -t 4 -r 1 -c 1 -1 /dev/ttyACM1
```

If the device answers, both the port and the parameters are confirmed — and you
also know the PLC runtime is already installed, so you can skip the bootloader
dance entirely. If it stays silent, try the other interface and other values.

In the verified setup the **second** interface (`-if02`, here `/dev/ttyACM1`,
COM2 in the IDE) answered with **38400 baud, no parity, 8 data bits, 1 stop bit,
Modbus address 247**. Values frequently quoted online — 115200, even parity,
address 1 — got no response from this device. Measuring beats copying.

Enter the values in the IDE under **On-line → Set up communication → Modbus**.

## Linux permissions

Two things, without which the port never shows up at all:

- **`dialout` group.** `sudo usermod -a -G dialout "$USER"`, then log out and
  back in.
- **Remove `brltty`.** It is a braille display service that claims Arduino
  boards on USB and makes the ports vanish immediately: `sudo apt remove brltty`.

`chmod 666 /dev/ttyACM*` is sometimes suggested; it is unnecessary once you are
in `dialout`, and it does not survive a reboot.

## Known issue

In the *Output* pane, Wine renders text rotated: each character is turned 90
degrees and lines run vertically. The content itself is correct — rotate a
screenshot back and you get the normal build messages ("Preprocessing …
compiled"). Window titles, menus and the project tree are unaffected.
Installing the standard fonts did not change it; the cause is the font Wine
picks for that one control. It is a display problem, not a functional one, but
it does make build output hard to read.

Fixes welcome.

## License

MIT — see [LICENSE](LICENSE).

Arduino, Opta and Portenta are trademarks of Arduino SA. This project is not
affiliated with or endorsed by Arduino SA. No Arduino software is redistributed
here; you need your own copy of the Arduino PLC IDE installer.
