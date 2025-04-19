#!/bin/bash

# Ordnerauswahl: Quelle
SRC=$(osascript <<EOT
    set srcFolder to choose folder with prompt "Wähle den QUELLORDNER auf der exFAT-Festplatte:"
    POSIX path of srcFolder
EOT
)

# Ordnerauswahl: Ziel
DST=$(osascript <<EOT
    set dstFolder to choose folder with prompt "Wähle den ZIELORDNER auf der Mac-Festplatte:"
    POSIX path of dstFolder
EOT
)

# Logfile
LOGFILE=~/rsync-copy-log.txt
echo "Starte Kopiervorgang am $(date)" > "$LOGFILE"
echo "Quelle: $SRC" | tee -a "$LOGFILE"
echo "Ziel:   $DST" | tee -a "$LOGFILE"

# Kopieren mit Fortschritt und Logging
rsync -ah --progress "$SRC" "$DST" | tee -a "$LOGFILE"

# Abschlussmeldung
osascript -e 'display dialog "Kopiervorgang abgeschlossen!" buttons {"OK"} default button "OK" with title "Fertig"'