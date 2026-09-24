# Arduino PLC IDE unter Linux: gepatchtes Wine 11

[English](README.md)

Community-Quellcodepatches, geprüft mit Arduino PLC IDE 1.1.0, Wine 11.0 und Linux Mint/Cinnamon (Muffin 6.6.3). Keine offizielle Arduino-/Wine-Veröffentlichung und kein vollständiger Binärinstaller.

## Geprüfter Stand — 24.09.2026

- Original-Skin, ST-Editor, HTML-Gerätekonfiguration, COM-Auswahl und I1–I8-Zuordnung funktionieren.
- Rein lokales Übersetzen: 0 Warnungen, 0 Fehler; Projektdateien unverändert.
- Lesende Modbus-Verbindung, wiederholtes Verbinden/Trennen und reguläres Beenden geprüft.
- CommServ 12.1.0.42 startet minimiert, bleibt manuell wiederherstellbar und endet beim Trennen.
- Keine Programm-/Firmwaredownloads, Resets, Halt/Run, Force oder Ausgangsschaltungen. Kein Geräteprogramm-Backup und kein Langzeit-Stabilitätsnachweis.

**Der frühere Rat, Gecko zu entfernen, ist überholt.** Der funktionierende gepatchte Stand benötigt Wine Gecko (geprüft: 2.47.4), englisches Zahlenformat (`LC_ALL=en_US.UTF-8`) sowie die VC-Laufzeit und nativen MSXML-Abhängigkeiten der Anwendung. Gecko entfernen oder nur den sichtbaren Skin abschalten war keine vollständige Reparatur.

Eine **eigene Wine-Laufzeit mit eigenem Prefix** verwenden; System-Wine nicht ersetzen. Im geprüften Prefix steht außerdem `FEATURE_BROWSER_EMULATION`, DWORD `Arduino PLC IDE.exe = 11001`, unter `HKCU\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION`. Keine pauschale Änderung fremder Anwendungen.

## Patches und Anwendung

Im Wurzelverzeichnis frischer [Wine-11.0-Quellen](https://github.com/wine-mirror/wine/tree/wine-11.0), in dieser Reihenfolge:

```sh
patch --fuzz=0 -p1 < /path/to/patches/wine-opta.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-beforescript.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-uxtheme-griff.patch
patch --fuzz=0 -p1 < /path/to/patches/wine-winex11-iconic.patch
```

Alle vier Patches wurden auf frische Upstream-Dateien ohne unscharfe Zuordnung angewandt und geprüft. Sie sind Community-Patches, nicht von Wine upstream angenommen; eine allgemeine Freigabe für andere Wine-Anwendungen ist damit nicht belegt.

1. `wine-opta.patch`: ActiveX-/IDispatch- und Vararg-Behandlung, Browser-Emulation, DOM-/Ereignis- und Skriptkompatibilität.
2. `wine-beforescript.patch`: BeforeScriptExecute vor Skriptausführung, damit der Host die Seitenvariablen vorbereiten kann.
3. `wine-uxtheme-griff.patch`: Fremde/ungültige Theme-Handles ablehnen statt abstürzen; Original-Skin bleibt aktiv. Gegenproben für gültige und ungültige Handles wurden durchgeführt.
4. `wine-winex11-iconic.patch`: Nach dem Mapping eines verwalteten, nicht eingebetteten Fensters mit anfänglichem IconicState genau einmal minimieren anfordern. Kein Timer, kein Versteckskript, keine Änderung des Desktop-Fenstermanagers.

Beim COM-Server meldete Wine Win32-seitig „minimiert“, Muffin stellte das X11-Fenster aber normal dar. Wine hielt diese Antwort für einen Zwischenzustand und wartete weiter auf Iconic. Original und Neubau ohne Patch reproduzierten das Problem; mit Patch wurden Iconic/HIDDEN und fortbestehendes CONNECTED gemessen. Auch die Windows-Referenz startete denselben Server minimiert, allerdings mit IDE 1.0.8 statt 1.1.0: kein vollständig versionsgleicher Gesamtvergleich.

**Die tatsächlich geladene Architektur bauen.** Im geprüften klassischen WoW64-Aufbau laden IDE und CommServ den Treiber `lib/wine/i386-unix/winex11.so`, obwohl Rechner und Prefix 64-Bit sind. Nur x86_64-unix auszutauschen prüft diese Korrektur nicht. Ladepfade über `/proc/<pid>/maps` kontrollieren; neue WoW64-Aufbauten können abweichen. Auch PE-DLLs müssen zur Prozessarchitektur passen. Nach Wines üblichen Bauanweisungen bauen, Originale sichern und nur bei beendetem eigenem Wine-Stand austauschen. Ein universeller Ein-Befehl-Binärinstaller ist hier nicht zugesagt.

## Installation und serielle Anschlüsse

Der geprüfte 1.1.0-WiX-Burn-Installer enthält einen angehängten CAB-Container; der Bootstrapper installierte unter Wine nicht korrekt. Die Fundstelle im eigenen offiziellen Installer prüfen, keinen festen Offset blind übernehmen:

```sh
grep -abo MSCF Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe
# OFFSET durch die bestätigte Fundstelle des angehängten Containers ersetzen:
dd if=Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe bs=1 skip=OFFSET of=container.cab status=none
cabextract container.cab
# Im geprüften Paket: a1 = Inno-Setup, a0 = Werkzeuge-MSI.
# Nur mit explizit gewähltem eigenem Wine und WINEPREFIX ausführen:
wine a1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
wine msiexec /i a0 /qn
```

Eigene offizielle Arduino-Installationsdatei verwenden; hier werden keine Arduino-Binärdateien verteilt. Konflikte mit Altinstallationen ausschließlich im eigenen Prefix beheben.

Wine kann beim Hochfahren `dosdevices/com*` überschreiben. Erst den eigenen Wine-Dienst initialisieren, danach die stabilen `/dev/serial/by-id/`-Schnittstellen auf niedrige COM-Nummern legen. Geprüft: if00 → COM1, if02 → COM2 und zusätzlich COM5 für ältere Projekte. Das vorhandene `plc-ide.sh` hilft bei dieser Zuordnung; es installiert weder diese Patches noch wählt es automatisch die gepatchte Laufzeit aus.

Geprüfte Verbindung: if02, Modbus RTU, 38400 Baud, keine Parität, 8 Datenbits, 1 Stoppbit, Adresse 247. Tatsächliche Geräteeinstellungen prüfen, keine universellen Standardwerte daraus ableiten. On-line → Set up communication, anschließend Connect; Download und Reset sind keine Verbindungstests. `DIFF. CODE` ist kein Auftrag, das laufende SPS-Programm zu überschreiben.

Serielle Zugriffsrechte prüfen (oft Gruppe dialout). Kein pauschales `chmod 666`; Barrierefreiheitssoftware wie brltty nicht ohne tatsächlich nachgewiesenen Konflikt entfernen.

## Lizenz und Grenzen

Bestehende Projekthelfer/Dokumentation behalten die [MIT-Lizenz](LICENSE). Änderungen am Wine-Quellcode stehen unter Wines LGPL-2.1-or-later-Bedingungen: [COPYING.Wine](COPYING.Wine) und Upstream-Quellhinweise beachten. Der neue Patchsatz enthält keine SPS-Anwendungsprogramme, privaten Installationspfade, Zugangsdaten oder Gerätekennungen. Keine Zugehörigkeit zu Arduino; Marken verbleiben bei ihren Inhabern.
