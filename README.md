# Arduino PLC IDE on Linux (Wine)

The Arduino PLC IDE is Windows-only. It **does** run under Wine — including a
working Modbus connection to an Arduino Opta — but two things stop you before
you get there. Both are solved here.

Verified on 2026-09-20: PLC IDE 1.1.0 under Wine 9.0 on Linux Mint, connected to
an Arduino Opta running PLC runtime 1.34.2:

```
Connected to ArduinoOpta_1p2 on ARMThumb2_VFP2.
Target runtime version: 1.34.2
Target system info: 1.2.0 ArduinoOpta
```

*(Deutsche Fassung: [README.de.md](README.de.md))*

## Use version 1.1.0 — older ones are broken under Wine

**PLC IDE 1.0.8 does not work under Wine.** It fails on startup with

```
Can not load device template 'LogicLab.pct' from Catalog!
Resources configuration will not be loaded.
```

The *Resources* section is then missing from the project tree — which is where
the device and connection settings live — and connecting fails with „Unable to
start the communication", without the IDE ever opening the serial port.

This is **not** a Wine configuration problem. Ruled out by testing, one at a
time: missing files, path case sensitivity, MSXML, COM registration of all six
components, XML validation in the template, the ToolkitPro library (byte-identical
between versions), the `Arduino\ArduinoPLC\InstallPath` registry key, and fonts.
Version 1.0.3 starts cleanly under the exact same Wine setup, so the cause is in
1.0.8's own code.

**1.1.0 fixes it.** The device catalog loads, the *Resources* tab is there, and
as a bonus the rotated-text glitch in the Output pane (every character turned 90°)
is gone too.

## Problem 1: the 1.1.0 installer is only a downloader

`Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe` is a WiX Burn bundle: it
fetches the real packages at runtime and **exits immediately under Wine**, with
no error message and nothing installed.

You do not need a Windows machine to get around this. Of its 55 MB, only ~0.5 MB
is the bootstrapper — the rest is an **attached CAB container** holding the real
installers. Cut it out and unpack it:

```bash
# find the attached container (take the second MSCF offset)
grep -abo MSCF Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe

# carve it out (replace 984408 with the offset you found) and unpack
dd if=Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe bs=1 skip=984408 \
   of=container.cab status=none
cabextract container.cab          # yields a0 (MSI, tools) and a1 (the real setup)
```

`a1` is a plain 32-bit Inno Setup installer and installs under Wine without
complaint:

```bash
wine a1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
wine msiexec /i a0 /qn            # the tools package
```

Note: the installer refuses to do anything if an older PLC IDE is still
installed — again without any message. Uninstall it first via
`"…/Arduino PLC IDE/unins000.exe" /VERYSILENT`.

## Problem 2: Wine rewrites the COM mapping while it boots

Wine maps Windows ports (COM1, COM2, …) through symlinks in the prefix's
`dosdevices` directory. An Opta appears as `/dev/ttyACM0` and `/dev/ttyACM1`,
which Wine assigns to high numbers such as COM35/COM36 — numbers the IDE does
not offer in its connection dialog.

Symlinking them to low numbers *before* starting **does not work**: while
booting, Wine enumerates the serial devices itself and overwrites
`dosdevices/com*` with the built-in ports (`/dev/ttyS0`, `/dev/ttyS1`, …). The
IDE then still lists COM1 and COM2, but there is a dead port behind them, and
connecting fails with „Unable to start the communication". This is the trap that
costs hours, because everything *looks* right.

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
reboots and replugging. `plc-ide.sh` does this in the right order.

**Tip:** if an existing project insists on, say, COM5, it is far easier to point
`dosdevices/com5` at the board than to fight the combo box in the connection
dialog.

## Quick start

```bash
sudo usermod -a -G dialout "$USER"   # then log out and back in
sudo apt remove brltty               # hijacks Arduino boards on USB

export WINEPREFIX=~/.local/share/arduino-plc-ide/wine
export WINEARCH=win64
winetricks -q vcrun2019 msxml3 msxml6
# unpack the installer as shown above, then:
wine a1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
wine msiexec /i a0 /qn

chmod +x plc-ide.sh
./plc-ide.sh 'C:\projects\demo\demo.plcprj'
```

Launch with `WINEDLLOVERRIDES="mscoree=d"` (the script sets it).

## Finding the right port and settings — by measuring, not guessing

The board exposes two serial interfaces. Which one answers, and with which
parameters, can be measured before touching the GUI. `mbpoll` only reads:

```bash
mbpoll -m rtu -b 38400 -P none -d 8 -s 1 -a 247 -t 4 -r 1 -c 1 -1 /dev/ttyACM1
```

If the device answers, port and parameters are confirmed — and you also know the
PLC runtime is already installed, so you can skip the bootloader procedure
entirely.

In the verified setup the **second** interface (`-if02`, here `/dev/ttyACM1`)
answered with **38400 baud, no parity, 8 data bits, 1 stop bit, Modbus address
247**. Values frequently quoted online — 115200, even parity, address 1 — got no
response from this device. Measuring beats copying.

Enter them under **On-line → Set up communication → Modbus → Properties**.

## Linux permissions

- **`dialout` group:** `sudo usermod -a -G dialout "$USER"`, then log out and in.
- **Remove `brltty`:** a braille service that claims Arduino boards on USB and
  makes the ports vanish: `sudo apt remove brltty`.

`chmod 666 /dev/ttyACM*` is unnecessary once you are in `dialout`, and does not
survive a reboot.

## License

MIT — see [LICENSE](LICENSE).

Arduino, Opta and Portenta are trademarks of Arduino SA. This project is not
affiliated with or endorsed by Arduino SA. No Arduino software is redistributed
here; you need your own copy of the installer.
