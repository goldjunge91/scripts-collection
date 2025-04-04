#!/bin/bash

# Raspberry Pi USB-Festplatten-Setup-Skript
# Dieses Skript richtet eine USB-Festplatte für den Raspberry Pi ein und
# konfiguriert sie als Mountpunkt für ausgewählte Verzeichnisse.

# Benötigt Root-Rechte
if [ "$(id -u)" -ne 0 ]; then
    echo "Dieses Skript muss mit Root-Rechten ausgeführt werden."
    echo "Bitte mit 'sudo $0' ausführen"
    exit 1
fi

echo "Raspberry Pi USB-Festplatten-Setup"
echo "=================================="
echo ""

# Verfügbare Laufwerke anzeigen
echo "Verfügbare Laufwerke:"
fdisk -l | grep -E "Disk /dev/(sd|mmcblk|nvme)" | sed 's/Disk //g' | sed 's/[:,].*//g'
echo ""

# Auswahl der Festplatte
read -p "Geben Sie das Gerät ein, das Sie verwenden möchten (z.B. /dev/sda): " DEVICE
echo ""

# Überprüfen, ob das Gerät existiert
if [ ! -b "$DEVICE" ]; then
    echo "Fehler: Das Gerät $DEVICE existiert nicht."
    exit 1
fi

# Sicherheitsabfrage
echo "WARNUNG: Alle Daten auf $DEVICE werden gelöscht!"
read -p "Sind Sie sicher, dass Sie fortfahren möchten? (j/n): " CONFIRM
if [ "$CONFIRM" != "j" ] && [ "$CONFIRM" != "J" ]; then
    echo "Vorgang abgebrochen."
    exit 0
fi

# Partitionierung der Festplatte
echo "Partitioniere die Festplatte $DEVICE..."
echo -e "o\nn\np\n1\n\n\nw" | fdisk "$DEVICE"

# Partition-Name ermitteln
if [[ "$DEVICE" == *"mmcblk"* ]] || [[ "$DEVICE" == *"nvme"* ]]; then
    PARTITION="${DEVICE}p1"
else
    PARTITION="${DEVICE}1"
fi

# Formatieren der Partition
echo "Formatiere Partition $PARTITION mit ext4..."
mkfs.ext4 -F "$PARTITION"

# UUID der Partition ermitteln
UUID=$(blkid -s UUID -o value "$PARTITION")
echo "UUID der Partition: $UUID"

# Mountpunkt erstellen
echo "Erstelle Mountpunkt..."
MOUNT_DIR="/mnt/usbdrive"
mkdir -p "$MOUNT_DIR"

# Temporäres Mounten
echo "Mounte Festplatte temporär..."
mount "$PARTITION" "$MOUNT_DIR"

# fstab-Eintrag vorbereiten ext4 defaults,auto,users,rw,exec,dev,suid,nofail 0 0
#FSTAB_ENTRY="UUID=$UUID $MOUNT_DIR ext4 defaults,auto,users,rw,nofail 0 0"
FSTAB_ENTRY="UUID=$UUID $MOUNT_DIR ext4 defaults,auto,users,rw,exec,dev,suid,nofail 0 0"
echo "Füge fstab-Eintrag hinzu:"
echo "$FSTAB_ENTRY"

# Prüfen, ob der Eintrag bereits existiert
if grep -q "$UUID" /etc/fstab; then
    echo "Eintrag existiert bereits in /etc/fstab."
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "Eintrag zu /etc/fstab hinzugefügt."
fi

# Menü zur Auswahl der Verzeichnisse, die auf die USB-Festplatte ausgelagert werden sollen
echo ""
echo "Welche Verzeichnisse möchten Sie auf die USB-Festplatte auslagern?"
echo "1) /home"
echo "2) /var"
echo "3) /opt"
echo "4) Benutzerdefiniertes Verzeichnis"
echo "5) Fertig"

DIRS_TO_MOVE=()

while true; do
    read -p "Wählen Sie eine Option (1-5): " CHOICE
    case "$CHOICE" in
        1) DIRS_TO_MOVE+=("/home") ;;
        2) DIRS_TO_MOVE+=("/var") ;;
        3) DIRS_TO_MOVE+=("/opt") ;;
        4) 
            read -p "Geben Sie das Verzeichnis ein: " CUSTOM_DIR
            DIRS_TO_MOVE+=("$CUSTOM_DIR") 
            ;;
        5) break ;;
        *) echo "Ungültige Auswahl." ;;
    esac
done

# Verzeichnisse # Verzeichnisse verschieben und in fstab eintragenverschieben und in fstab eintragen
for DIR in "${DIRS_TO_MOVE[@]}"; do
    TARGET_DIR="$MOUNT_DIR$(echo $DIR | sed 's/^\///')"
    
    # Überprüfen, ob das Zielverzeichnis existiert
    if [ -d "$DIR" ]; then
        echo ""
        echo "Verarbeite Verzeichnis: $DIR"
        
        # Zielverzeichnis erstellen
        mkdir -p "$TARGET_DIR"
        
        # Daten kopieren
        echo "Kopiere Daten von $DIR nach $TARGET_DIR..."
        rsync -avx "$DIR/" "$TARGET_DIR/"
        
        # Originalverzeichnis umbenennen
        echo "Benenne $DIR um zu ${DIR}.old..."
        mv "$DIR" "${DIR}.old"
        
        # Neues Verzeichnis erstellen
        mkdir -p "$DIR"
        
        # fstab-Eintrag für das Verzeichnis
        BIND_ENTRY="$TARGET_DIR $DIR none bind 0 0"
        
        # Prüfen, ob der Eintrag bereits existiert
        if grep -q "$BIND_ENTRY" /etc/fstab; then
            echo "Bind-Mount existiert bereits in /etc/fstab."
        else
            echo "$BIND_ENTRY" >> /etc/fstab
            echo "Bind-Mount zu /etc/fstab hinzugefügt."
        fi
    else
        echo "Verzeichnis $DIR existiert nicht. Überspringe..."
    fi
done

# Änderungen anwenden
echo ""
echo "Wende alle Änderungen an..."
mount -a

echo ""
echo "Setup abgeschlossen."
echo "Die USB-Festplatte ist unter $MOUNT_DIR gemountet."
if [ ${#DIRS_TO_MOVE[@]} -gt 0 ]; then
    echo "Folgende Verzeichnisse wurden auf die USB-Festplatte ausgelagert:"
    for DIR in "${DIRS_TO_MOVE[@]}"; do
        echo "- $DIR"
    done
fi
echo ""
echo "Wichtig: Überprüfen Sie die Funktionalität, bevor Sie die .old-Verzeichnisse löschen!"
echo "Zum Löschen der Sicherungen führen Sie aus: rm -rf /path/to/directory.old"