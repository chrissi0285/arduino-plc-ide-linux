# Arduino PLC IDE on Linux: patched Wine 11

[Deutsch](README.de.md)

Community source patches tested with Arduino PLC IDE 1.1.0, Wine 11.0 and Linux Mint/Cinnamon (Muffin 6.6.3). This is not an official Arduino/Wine release or a complete binary installer.

## Current verified status — 2026-09-24

- Original IDE skin, ST editor, HTML device configuration, COM selection and I1–I8 mapping render correctly.
- Offline compilation: 0 warnings, 0 errors. Project files remained unchanged.
- Read-only Modbus connections work; repeated connect/disconnect tests passed and the IDE exits normally.
- CommServ 12.1.0.42 starts minimized. Manual restore remains possible; disconnect ends the server process.
- No firmware/program download, reset, halt/run, force or output switching was performed. These tests are not a device-program backup or a long-term stability guarantee.

**Earlier advice to remove Gecko is superseded.** The working patched setup needs Wine Gecko (tested 2.47.4), an English numeric locale (`LC_ALL=en_US.UTF-8`), and the application's VC runtime and native MSXML dependencies. Removing Gecko or disabling the visible skin did not provide a complete repair.

Use a **dedicated Wine runtime and prefix**, not a replacement for system Wine. The tested prefix also has `FEATURE_BROWSER_EMULATION` DWORD `Arduino PLC IDE.exe = 11001` under `HKCU\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION`. Do not apply these settings to unrelated applications.

## Source patches

Apply these in order to fresh [Wine 11.0 sources](https://github.com/wine-mirror/wine/tree/wine-11.0), from the source root:

```sh
patch --fuzz=0 -p1 < /path/to/patches/wine-opta.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-beforescript.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-uxtheme-griff.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-winex11-iconic.patch
```

All four patches were checked and applied to fresh upstream Wine 11.0 files without fuzzy matching. They are community patches, not upstream-accepted fixes, and need broader regression coverage before general Wine deployment.

1. `wine-opta.patch`: embedded ActiveX/IDispatch and vararg handling, browser-emulation configuration, DOM/event and script compatibility.
2. `wine-beforescript.patch`: emits BeforeScriptExecute before scripts run, allowing the host to initialize page variables.
3. `wine-uxtheme-griff.patch`: rejects foreign/invalid theme handles instead of dereferencing them. Original skin remains enabled. Valid-handle and invalid-handle countertests accompanied the application tests.
4. `wine-winex11-iconic.patch`: after mapping a managed, non-embedded window that requests initial IconicState, explicitly requests iconification once. No timer, launcher hide-loop or desktop-window-manager change.

For the last issue Wine reported a minimized Win32 window, but Muffin mapped it as X11 Normal. Wine treated that Normal notification as transient and kept waiting for Iconic. Original and unpatched-rebuild countertests reproduced it; the patched driver gave X11 Iconic/HIDDEN with the IDE still CONNECTED. A Windows reference also started the same CommServ binary minimized; its IDE was 1.0.8 rather than 1.1.0, so this was not an identical full-stack comparison.

**Build/install for the architecture actually loaded.** The tested traditional WoW64 runtime loads `lib/wine/i386-unix/winex11.so` in the 32-bit IDE and CommServ, even though the machine/prefix are 64-bit. Updating only x86_64-unix does not test this correction. Verify `/proc/<pid>/maps`; new-WoW64 layouts may differ. The PE DLLs also need to match the process architecture. Build using Wine's normal dependencies and instructions, preserve originals, and replace files only after closing the dedicated runtime. No portable one-command binary installation is claimed here.

## Installer and serial-port notes

The 1.1.0 WiX Burn installer contained an attached CAB in the tested download. Its bootstrapper did not install correctly under Wine. Find the attached container in your own installer rather than assuming a fixed offset:

```sh
grep -abo MSCF Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe
# Use the verified attached-container offset from that file:
dd if=Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe bs=1 skip=OFFSET of=container.cab status=none
cabextract container.cab
# In the tested bundle: a1 = Inno Setup; a0 = tools MSI.
# Run with the explicitly selected dedicated Wine and WINEPREFIX:
wine a1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
wine msiexec /i a0 /qn
```

Use your own official Arduino installer; no Arduino binaries are redistributed. Resolve old-install conflicts only inside the dedicated prefix.

Wine boot can overwrite `dosdevices/com*`. Start/initialize the **dedicated** Wine server first, then map the Opta's stable `/dev/serial/by-id/` interfaces to low COM numbers. In the tested setup if00 maps to COM1, if02 to COM2 and additionally COM5 for older project settings. `plc-ide.sh` is the existing COM-mapping helper; it does **not** install this patch set or select the patched runtime for you.

The tested connection used if02, Modbus RTU, 38400 baud, no parity, 8 data bits, 1 stop bit, address 247. Confirm the actual device configuration rather than treating these as universal defaults. Use On-line → Set up communication, then Connect. Do not use Download or reset actions as a connection test. `DIFF. CODE` is not an instruction to overwrite the running PLC program.

Check serial access permissions (commonly the dialout group). Do not use blanket `chmod 666` or remove accessibility software such as brltty without diagnosing an actual conflict.

## License and scope

Existing project helpers/documentation retain the [MIT license](LICENSE). Patches modifying Wine source are provided under Wine's LGPL-2.1-or-later terms; see [COPYING.Wine](COPYING.Wine) and the upstream source notices. No PLC application source, private installation paths, credentials or device identifiers are included in the new patch set. Arduino trademarks belong to their respective owners; this project is unaffiliated.
