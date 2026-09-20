# Arduino PLC IDE unter Linux mit Wine betreiben

Die Arduino PLC IDE gibt es nur für Windows. Sie läuft aber unter Wine — samt
Modbus-Verbindung zu einem Arduino Opta. Zwei Dinge stehen dem im Weg; beide
sind hier gelöst.

Belegt am 20.09.2026: PLC IDE 1.1.0 unter Wine 9.0 auf Linux Mint, verbunden mit
einem Arduino Opta mit Laufzeitumgebung 1.34.2:

    Connected to ArduinoOpta_1p2 on ARMThumb2_VFP2.
    Target runtime version: 1.34.2
    Target system info: 1.2.0 ArduinoOpta

## Version 1.1.0 verwenden — ältere sind unter Wine defekt

**Version 1.0.8 funktioniert unter Wine nicht.** Sie meldet beim Start:

    Can not load device template 'LogicLab.pct' from Catalog!
    Resources configuration will not be loaded.

Danach fehlt im Projektbaum der Bereich *Resources* — genau dort sitzen die
Geräte- und Verbindungseinstellungen — und der Verbindungsversuch scheitert mit
„Unable to start the communication", ohne dass die IDE die serielle
Schnittstelle überhaupt öffnet.

Das liegt **nicht** an der Wine-Einrichtung. Einzeln geprüft und ausgeschlossen:
fehlende Dateien, Groß-/Kleinschreibung der Pfade, MSXML, die COM-Registrierung
aller sechs Komponenten, die XML-Validierung im Template, die Bibliothek
ToolkitPro (in beiden Fassungen byte-identisch), der Registrierungseintrag
`Arduino\ArduinoPLC\InstallPath` und die Schriftarten. Version 1.0.3 startet
unter derselben Wine-Einrichtung sauber — die Ursache liegt also im Programmcode
von 1.0.8.

**1.1.0 behebt das.** Der Gerätekatalog lädt, der Reiter *Resources* ist da, und
nebenbei verschwindet auch der Darstellungsfehler im Ausgabefenster, bei dem
jeder Buchstabe um 90 Grad gedreht war.

Version 1.0.3 taugt nicht als Ausweg: Ihr Katalog kennt nur `ArduinoOpta_1p0`.
Kopiert man die neueren Gerätedefinitionen hinein, stürzt sie beim Öffnen eines
mit 1.0.8 erstellten Projekts ab.

## Stolperstein 1: Der 1.1.0-Installer ist nur ein Downloader

`Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe` ist ein WiX-Burn-Paket: Es
holt die eigentliche Software erst zur Laufzeit aus dem Netz und **bricht unter
Wine sofort ab** — ohne Fehlermeldung und ohne irgendetwas zu installieren.

Dafür braucht es keinen Windows-Rechner. Von den 55 MB sind nur etwa 0,5 MB die
Hülle; der Rest ist ein **angehängter CAB-Container** mit den echten Installern.
Herausschneiden und entpacken:

    # angehängten Container finden (die zweite MSCF-Fundstelle nehmen)
    grep -abo MSCF Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe

    # herausschneiden (984408 durch die gefundene Zahl ersetzen) und entpacken
    dd if=Arduino-PLC-IDE-Installer_1.1.0_Windows_64bit.exe bs=1 skip=984408 \
       of=container.cab status=none
    cabextract container.cab      # ergibt a0 (MSI, Werkzeuge) und a1 (echter Setup)

`a1` ist ein gewöhnliches 32-Bit-Inno-Setup und installiert unter Wine ohne Murren:

    wine a1 /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
    wine msiexec /i a0 /qn


**Wichtig:** Der Installer tut nichts, solange eine ältere PLC IDE installiert
ist — ebenfalls ohne jede Meldung. Vorher entfernen mit
`"…/Arduino PLC IDE/unins000.exe" /VERYSILENT`.

## Stolperstein 2: Wine überschreibt die COM-Zuordnung beim Start

Wine bildet Windows-Anschlüsse (COM1, COM2 …) über Verweise im Ordner
`dosdevices` des Prefix ab. Der Opta meldet sich als `/dev/ttyACM0` und
`/dev/ttyACM1`; Wine legt diese auf hohe Nummern wie COM35/COM36, die die IDE im
Verbindungsdialog nicht anbietet.

Die Verweise **vor** dem Start auf niedrige Nummern zu legen, funktioniert
nicht: Beim Hochfahren durchsucht Wine selbst die seriellen Geräte und
überschreibt `dosdevices/com*` mit den eingebauten Anschlüssen (`/dev/ttyS0`,
`/dev/ttyS1` …). Die IDE zeigt dann zwar COM1 und COM2 an, dahinter liegt aber
ein toter Anschluss, und sie meldet „Unable to start the communication". Das ist
die Falle, die Stunden kostet, weil alles richtig *aussieht*.

**Lösung:** Erst den Wine-Dienst hochfahren, *danach* die Verweise setzen:

    wineserver -k          # laufende Wine-Prozesse beenden
    wineserver -p          # Dienst offen halten, sonst fährt er erneut hoch
    wine wineboot          # hier erzeugt Wine seine eigene COM-Zuordnung
    ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<Seriennummer>-if00 "$WINEPREFIX/dosdevices/com1"
    ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<Seriennummer>-if02 "$WINEPREFIX/dosdevices/com2"
    wine "…/Arduino PLC IDE.exe"

Der Weg über `/dev/serial/by-id/` statt über `/dev/ttyACM*` sorgt dafür, dass
die Zuordnung Neustart und Umstecken übersteht. Das Skript `plc-ide.sh`
erledigt das in der richtigen Reihenfolge.

**Praktischer Kniff:** Verlangt ein vorhandenes Projekt zum Beispiel COM5, ist
es viel einfacher, `dosdevices/com5` auf das Gerät zu legen, als im
Verbindungsdialog das Auswahlfeld umzustellen.

## Vorbereitung des Prefix

    export WINEPREFIX=~/.local/share/arduino-plc-ide/wine
    export WINEARCH=win64
    winetricks -q vcrun2019 msxml3 msxml6

Gestartet wird mit `WINEDLLOVERRIDES="mscoree=d"` (das Startskript setzt das).

## Zugriff auf die Schnittstelle unter Linux

    sudo usermod -a -G dialout $USER   # danach ab- und wieder anmelden
    sudo apt remove brltty             # blockiert sonst Arduino-Geräte am USB

`brltty` ist eine Hilfe für Blindenschrift-Zeilen, die Arduino-Boards
fälschlicherweise für sich beansprucht und die Anschlüsse sofort wieder
verschwinden lässt. `chmod 666 /dev/ttyACM*` ist unnötig, sobald man in der
Gruppe `dialout` ist, und übersteht keinen Neustart.

## Die richtigen Verbindungswerte finden — messen statt raten

Der Opta meldet zwei serielle Schnittstellen. Welche antwortet und mit welchen
Werten, lässt sich vor jedem Oberflächenversuch messen. `mbpoll` liest nur und
verändert nichts am Gerät:

    mbpoll -m rtu -b 38400 -P none -d 8 -s 1 -a 247 -t 4 -r 1 -c 1 -1 /dev/ttyACM1

Antwortet das Gerät, sind Anschluss und Werte belegt — und man weiß zugleich,
dass die PLC-Laufzeitumgebung bereits aufgespielt ist, kann sich das Aufspielen
im Bootloader-Modus also sparen.

Im geprüften Fall antwortete die **zweite** Schnittstelle (`-if02`, hier
`/dev/ttyACM1`) mit **38400 Baud, keine Parität, 8 Datenbits, 1 Stoppbit,
Modbus-Adresse 247**. Häufig im Netz genannte Werte wie 115200 mit gerader
Parität und Adresse 1 blieben bei diesem Gerät ohne Antwort.

Einzutragen unter **On-line → Set up communication → Modbus → Properties**.

## Hinweis zur Statusanzeige

Nach dem Verbinden zeigt die Statusleiste neben „CONNECTED" oft „DIFF. CODE".
Das bedeutet nur, dass der Programmstand im Gerät nicht bitgleich zum geöffneten
Projekt ist. Es ist **kein** Beleg dafür, dass das Projekt falsch wäre — auch
unveränderter Quelltext erzeugt in neueren IDE-Fassungen einen anderen
Codestand.
