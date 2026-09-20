# Arduino PLC IDE unter Linux mit Wine betreiben

Die Arduino PLC IDE gibt es nur für Windows. Sie läuft aber unter Wine — inklusive
Verbindung zu einem angeschlossenen Arduino Opta. Diese Anleitung beschreibt die
beiden Stolpersteine, an denen es sonst scheitert, und wie man sie umgeht.

Geprüft am 20.09.2026 mit Arduino PLC IDE 1.0.8, Wine 9.0 (32-Bit-Prefix),
Linux Mint, Arduino Opta mit PLC-Laufzeitumgebung 1.34.2.

## Stolperstein 1: Wine überschreibt die COM-Zuordnung beim Start

Wine bildet Windows-Anschlüsse (COM1, COM2 …) über Verweise im Ordner
`dosdevices` des Prefix ab. Der Opta meldet sich unter Linux als `/dev/ttyACM0`
und `/dev/ttyACM1`; Wine legt diese aber auf hohe Nummern wie COM35/COM36, die
die IDE im Verbindungsdialog gar nicht anbietet.

Der naheliegende Griff — die Verweise vor dem Start auf niedrige Nummern legen —
**funktioniert nicht**: Beim Hochfahren durchsucht Wine selbst die seriellen
Geräte und überschreibt `dosdevices/com*` wieder mit den eingebauten Anschlüssen
(`/dev/ttyS0`, `/dev/ttyS1` …). Die IDE zeigt dann zwar COM1 und COM2 an,
dahinter liegt aber ein toter Anschluss, und sie meldet beim Verbinden:

    Unable to start the communication
    Choose 'On-line / Set up communication' to configure it

**Lösung:** Erst den Wine-Dienst hochfahren, *danach* die Verweise setzen:

    wineserver -k          # laufende Wine-Prozesse beenden
    wineserver -p          # Dienst offen halten, sonst fährt er erneut hoch
    wine wineboot          # hier erzeugt Wine seine eigene COM-Zuordnung
    ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<Seriennummer>-if00 "$WINEPREFIX/dosdevices/com1"
    ln -sfn /dev/serial/by-id/usb-Arduino_Arduino_Opta_<Seriennummer>-if02 "$WINEPREFIX/dosdevices/com2"
    wine "…/Arduino PLC IDE.exe"

Der Weg über `/dev/serial/by-id/` statt über `/dev/ttyACM*` ist wichtig, damit die
Zuordnung einen Neustart und das Umstecken übersteht. Das beiliegende Skript
`plc-ide.sh` erledigt das in der richtigen Reihenfolge und findet die
Seriennummer selbst.

## Stolperstein 2: „Can not load device template … from Catalog"

Beim Start meldet die IDE:

    Can not load device template 'LogicLab.pct' from Catalog!
    Resources configuration will not be loaded.

Folge: Im Projektbaum fehlt der Bereich *Resources* — und genau dort sitzen die
Geräte- und Verbindungseinstellungen.

**Lösung:** Wines HTML-Nachbau abschalten, bevor die IDE startet:

    export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

Danach lädt die Konfiguration durch und der Projektbaum ist vollständig.

## Vorbereitung des Prefix

32-Bit-Prefix anlegen und die Laufzeitbibliotheken nachrüsten:

    export WINEPREFIX=~/plc-ide
    export WINEARCH=win32
    winetricks -q vcrun2019 msxml3 msxml6

Danach das Windows-Installationsprogramm der PLC IDE unter Wine ausführen.

## Zugriff auf die Schnittstelle unter Linux

Zwei Punkte, ohne die der Anschluss gar nicht erst auftaucht:

    sudo usermod -a -G dialout $USER   # danach ab- und wieder anmelden
    sudo apt remove brltty             # blockiert sonst Arduino-Geräte am USB

`brltty` ist eine Hilfe für Blindenschrift-Zeilen, die fälschlicherweise
Arduino-Boards für sich beansprucht und die Anschlüsse sofort wieder verschwinden
lässt.

## Die richtigen Verbindungswerte finden — ohne Raten

Der Opta meldet zwei serielle Schnittstellen. Welche antwortet und mit welchen
Werten, lässt sich vor jedem Oberflächenversuch direkt messen, zum Beispiel mit
`mbpoll` (nur lesender Zugriff, verändert nichts am Gerät):

    mbpoll -m rtu -b 38400 -P none -d 8 -s 1 -a 247 -t 4 -r 1 -c 1 -1 /dev/ttyACM1

Antwortet das Gerät, sind Anschluss und Werte belegt — und man weiß zugleich, dass
die PLC-Laufzeitumgebung bereits aufgespielt ist. Bleibt es still, die andere
Schnittstelle und andere Werte durchprobieren.

Im geprüften Fall antwortete die **zweite** Schnittstelle (`-if02`, hier
`/dev/ttyACM1`, in der IDE COM2) mit **38400 Baud, keine Parität, 8 Datenbits,
1 Stoppbit, Modbus-Adresse 247**. Häufig im Netz genannte Werte wie 115200 mit
gerader Parität und Adresse 1 blieben bei diesem Gerät ohne Antwort — deshalb
lohnt das Messen mehr als das Übernehmen fremder Angaben.

In der IDE einzutragen unter: **On-line → Set up communication → Modbus**.

## Bekannte Einschränkung

Im Ausgabefenster (*Output*) stellt Wine den Text verdreht dar: Jeder Buchstabe
ist um 90 Grad gedreht, die Zeilen laufen senkrecht. Der Inhalt selbst ist
korrekt — dreht man einen Bildschirmausschnitt zurück, stehen dort die normalen
Übersetzungsmeldungen („Preprocessing … compiled"). Fensterüberschriften und
Menüs sind nicht betroffen. Standardschriften nachzuinstallieren hat daran nichts
geändert; die Ursache liegt in der Schriftwahl, die Wine für dieses eine
Textfeld trifft. Ein Funktionsfehler ist es nicht, aber Meldungen sind so nur
mühsam zu lesen.
