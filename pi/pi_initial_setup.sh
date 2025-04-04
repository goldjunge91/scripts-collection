#!/bin/bash

# Raspberry Pi 4B Initial Setup Script
# Dieses Skript führt die Schritte 1 und 2 der Raspberry Pi-Einrichtung durch:
# 1. SD-Karte vorbereiten
# 2. Grundeinrichtung des Raspberry Pi

# Prüfen, ob das Skript als Root ausgeführt wird (für macOS)
if [ "$(id -u)" -ne 0 ] && [ "$(uname)" == "Darwin" ]; then
    echo "Dieses Skript benötigt Admin-Rechte auf macOS für einige Operationen."
    echo "Bitte mit 'sudo $0' ausführen"
    exit 1
fi

# Variablen
RPI_OS_URL="https://downloads.raspberrypi.org/raspios_lite_armhf_latest"
DOWNLOAD_DIR="${HOME}/Downloads"
RPI_OS_ZIP="${DOWNLOAD_DIR}/raspios_lite_armhf_latest.zip"
RPI_OS_IMG=""
SSH_PUBKEY="${HOME}/.ssh/id_rsa.pub"
HOSTNAME="raspberrypi"
WIFI_SSID=""
WIFI_PASSWORD=""
SETUP_USB_SCRIPT="/Users/marco/scripts-collection/pi_usb_drive_setup.sh"

# Farbdefinitionen für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion: Fehleranzeige und Beenden
error_exit() {
    echo -e "${RED}Fehler: $1${NC}" >&2
    exit 1
}

# Funktion: Informationsnachricht
info() {
    echo -e "${BLUE}Info: $1${NC}"
}

# Funktion: Erfolgsmeldung
success() {
    echo -e "${GREEN}Erfolg: $1${NC}"
}

# Funktion: Warnung
warning() {
    echo -e "${YELLOW}Warnung: $1${NC}"
}

# Funktion: Überprüfen, ob ein Befehl existiert
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Abfrage der Konfigurationsdetails
get_config_details() {
    echo "==================================="
    echo "Raspberry Pi 4B Einrichtungs-Skript"
    echo "==================================="
    echo ""
    
    read -p "Geben Sie den Hostnamen für den Raspberry Pi ein [raspberrypi]: " input_hostname
    HOSTNAME=${input_hostname:-$HOSTNAME}
    
    # WiFi-Konfiguration (optional)
    read -p "Möchten Sie WiFi konfigurieren? (j/n): " setup_wifi
    if [ "$setup_wifi" == "j" ] || [ "$setup_wifi" == "J" ]; then
        read -p "Geben Sie den WiFi-SSID (Netzwerkname) ein: " WIFI_SSID
        read -s -p "Geben Sie das WiFi-Passwort ein: " WIFI_PASSWORD
        echo ""
    fi
    
    # SSH Pubkey
    if [ -f "$SSH_PUBKEY" ]; then
        read -p "Möchten Sie den vorhandenen SSH-Schlüssel verwenden? ($SSH_PUBKEY) (j/n): " use_existing_key
        if [ "$use_existing_key" != "j" ] && [ "$use_existing_key" != "J" ]; then
            read -p "Geben Sie den Pfad zu Ihrem SSH Public Key ein: " SSH_PUBKEY
        fi
    else
        read -p "SSH-Schlüssel nicht gefunden. Geben Sie den Pfad zu Ihrem SSH Public Key ein: " SSH_PUBKEY
    fi
    
    # Bestätigung
    echo ""
    echo "Die folgenden Einstellungen werden verwendet:"
    echo "Hostname: $HOSTNAME"
    if [ -n "$WIFI_SSID" ]; then
        echo "WiFi-SSID: $WIFI_SSID"
    else
        echo "WiFi: Nicht konfiguriert"
    fi
    echo "SSH-Schlüssel: $SSH_PUBKEY"
    echo ""
    
    read -p "Sind diese Einstellungen korrekt? (j/n): " confirm
    if [ "$confirm" != "j" ] && [ "$confirm" != "J" ]; then
        echo "Einrichtung abgebrochen. Starten Sie das Skript erneut."
        exit 0
    fi
}

# Prüfen und installieren der benötigten Tools
check_requirements() {
    info "Prüfe benötigte Tools..."
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - Prüfen, ob Homebrew installiert ist
        if ! command_exists brew; then
            warning "Homebrew ist nicht installiert. Es wird für die Installation von benötigten Tools empfohlen."
            read -p "Möchten Sie Homebrew installieren? (j/n): " install_brew
            if [ "$install_brew" == "j" ] || [ "$install_brew" == "J" ]; then
                info "Installiere Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Homebrew-Installation fehlgeschlagen."
            else
                warning "Ohne Homebrew könnten einige Tools fehlen."
            fi
        fi
        
        # Prüfen und installieren der benötigten Tools
        for tool in curl wget pv; do
            if ! command_exists $tool; then
                info "$tool wird installiert..."
                brew install $tool || warning "Installation von $tool fehlgeschlagen. Einige Funktionen könnten nicht verfügbar sein."
            fi
        done
    elif [ "$(uname)" == "Linux" ]; then
        # Linux - Abhängig von der Distribution
        if command_exists apt-get; then
            info "Aktualisiere Paketlisten..."
            apt-get update
            
            info "Installiere benötigte Pakete..."
            apt-get install -y curl wget pv zip unzip || warning "Paketinstallation fehlgeschlagen. Einige Funktionen könnten nicht verfügbar sein."
        elif command_exists dnf; then
            info "Installiere benötigte Pakete..."
            dnf install -y curl wget pv zip unzip || warning "Paketinstallation fehlgeschlagen. Einige Funktionen könnten nicht verfügbar sein."
        else
            warning "Unbekanntes Linux-System. Bitte installieren Sie curl, wget, pv, zip und unzip manuell."
        fi
    else
        warning "Nicht unterstütztes Betriebssystem: $(uname). Einige Funktionen könnten nicht funktionieren."
    fi
    
    success "Prüfung der Tools abgeschlossen."
}

# Raspberry Pi OS herunterladen
download_os() {
    info "Prüfe, ob Raspberry Pi OS bereits heruntergeladen wurde..."
    
    # Verzeichnis erstellen, falls es nicht existiert
    mkdir -p "$DOWNLOAD_DIR"
    
    # Herunterladen des Raspberry Pi OS, falls nötig
    if [ ! -f "$RPI_OS_ZIP" ]; then
        info "Lade Raspberry Pi OS herunter..."
        wget -O "$RPI_OS_ZIP" "$RPI_OS_URL" || curl -L -o "$RPI_OS_ZIP" "$RPI_OS_URL" || error_exit "Download fehlgeschlagen."
    else
        info "Raspberry Pi OS ZIP-Datei gefunden: $RPI_OS_ZIP"
    fi
    
    # Entpacken des Images
    info "Entpacke ZIP-Datei..."
    unzip -o "$RPI_OS_ZIP" -d "$DOWNLOAD_DIR" || error_exit "Entpacken fehlgeschlagen."
    
    # Finde die IMG-Datei
    RPI_OS_IMG=$(find "$DOWNLOAD_DIR" -name "*.img" -type f -depth 1 | head -n 1)
    
    if [ -z "$RPI_OS_IMG" ]; then
        error_exit "Konnte keine IMG-Datei im Verzeichnis $DOWNLOAD_DIR finden."
    fi
    
    success "Raspberry Pi OS Image: $RPI_OS_IMG"
}

# SD-Karte auswählen
select_sd_card() {
    if [ "$(uname)" == "Darwin" ]; then
        echo "Verfügbare Laufwerke:"
        diskutil list
        
        echo ""
        read -p "Geben Sie den Disk-Identifier der SD-Karte ein (z.B. disk2): " SD_CARD
        
        # Validieren
        if ! diskutil info "/dev/$SD_CARD" > /dev/null 2>&1; then
            error_exit "Ungültiger Disk-Identifier: /dev/$SD_CARD"
        fi
        
        # Warnung und Bestätigung
        echo ""
        echo -e "${RED}WARNUNG: ALLE DATEN AUF /dev/$SD_CARD WERDEN GELÖSCHT!${NC}"
        echo "Stellen Sie sicher, dass dies die richtige SD-Karte ist."
        read -p "Sind Sie sicher, dass Sie fortfahren möchten? (j/n): " confirm
        
        if [ "$confirm" != "j" ] && [ "$confirm" != "J" ]; then
            echo "Abgebrochen."
            exit 0
        fi
        
        # Unmounten der SD-Karte
        info "Unmounte /dev/$SD_CARD..."
        diskutil unmountDisk "/dev/$SD_CARD" || error_exit "Unmount fehlgeschlagen."
    else
        echo "Verfügbare Laufwerke:"
        lsblk
        
        echo ""
        read -p "Geben Sie den Device-Namen der SD-Karte ein (z.B. sdb): " SD_CARD
        
        # Warnung und Bestätigung
        echo ""
        echo -e "${RED}WARNUNG: ALLE DATEN AUF /dev/$SD_CARD WERDEN GELÖSCHT!${NC}"
        echo "Stellen Sie sicher, dass dies die richtige SD-Karte ist."
        read -p "Sind Sie sicher, dass Sie fortfahren möchten? (j/n): " confirm
        
        if [ "$confirm" != "j" ] && [ "$confirm" != "J" ]; then
            echo "Abgebrochen."
            exit 0
        fi
        
        # Unmounten aller Partitionen der SD-Karte
        info "Unmounte alle Partitionen von /dev/$SD_CARD..."
        for partition in $(ls /dev/${SD_CARD}* 2>/dev/null); do
            if mount | grep -q "$partition"; then
                umount "$partition" || warning "Unmount von $partition fehlgeschlagen."
            fi
        done
    fi
}

# Schreiben des OS-Images auf die SD-Karte
flash_sd_card() {
    info "Schreibe Image auf SD-Karte..."
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - mit dd schreiben
        if command_exists pv; then
            # Mit Fortschrittsanzeige
            pv "$RPI_OS_IMG" | dd of="/dev/r$SD_CARD" bs=1m
        else
            # Ohne Fortschrittsanzeige
            dd if="$RPI_OS_IMG" of="/dev/r$SD_CARD" bs=1m
        fi
        
        # Auswerfen der SD-Karte
        diskutil eject "/dev/$SD_CARD"
    else
        # Linux - mit dd schreiben
        if command_exists pv; then
            # Mit Fortschrittsanzeige
            pv "$RPI_OS_IMG" | dd of="/dev/$SD_CARD" bs=4M conv=fsync status=progress
        else
            # Ohne Fortschrittsanzeige
            dd if="$RPI_OS_IMG" of="/dev/$SD_CARD" bs=4M conv=fsync status=progress
        fi
        
        # Sync, um sicherzustellen, dass alle Daten geschrieben wurden
        sync
    fi
    
    success "Image erfolgreich auf SD-Karte geschrieben."
    
    # Warten, bis das Betriebssystem die SD-Karte wieder erkennt
    echo "Warte 5 Sekunden, bis die SD-Karte wieder erkannt wird..."
    sleep 5
}

# SD-Karte mounten, um sie zu konfigurieren
mount_sd_card() {
    info "Mounte die SD-Karte, um sie zu konfigurieren..."
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS - Automatisches Mounten durch das Betriebssystem
        BOOT_MOUNT=$(df -h | grep "boot" | awk '{print $9}')
        
        if [ -z "$BOOT_MOUNT" ]; then
            # Versuchen, die Boot-Partition zu finden
            diskutil list | grep -A 5 "$SD_CARD"
            
            read -p "Geben Sie die Boot-Partition ein (z.B. ${SD_CARD}s1): " BOOT_PART
            diskutil mount "/dev/$BOOT_PART" || error_exit "Mounten der Boot-Partition fehlgeschlagen."
            
            BOOT_MOUNT=$(df -h | grep "$BOOT_PART" | awk '{print $9}')
        fi
    else
        # Linux - Manuelles Mounten
        BOOT_MOUNT="/mnt/boot"
        mkdir -p "$BOOT_MOUNT"
        
        # Finde die Boot-Partition
        BOOT_PART="${SD_CARD}1"
        
        # Mounten der Boot-Partition
        mount "/dev/$BOOT_PART" "$BOOT_MOUNT" || error_exit "Mounten der Boot-Partition fehlgeschlagen."
    fi
    
    if [ -z "$BOOT_MOUNT" ] || [ ! -d "$BOOT_MOUNT" ]; then
        error_exit "Boot-Partition nicht gefunden oder nicht zugänglich."
    fi
    
    success "SD-Karte erfolgreich gemountet: $BOOT_MOUNT"
}

# SSH aktivieren und weitere Konfigurationen vornehmen
configure_sd_card() {
    info "Konfiguriere SD-Karte..."
    
    # SSH aktivieren
    info "Aktiviere SSH..."
    touch "${BOOT_MOUNT}/ssh" || warning "Konnte SSH-Datei nicht erstellen."
    
    # WiFi konfigurieren, falls angegeben
    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
        info "Konfiguriere WLAN..."
        cat > "${BOOT_MOUNT}/wpa_supplicant.conf" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE

network={
    ssid="$WIFI_SSID"
    pss="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
    fi
    
    # userconf.txt für Benutzer pi und Passwort 'raspberry' erstellen
    # Hinweis: Dies funktioniert nur mit neueren Raspberry Pi OS Versionen
    info "Setze Standardpasswort für den Benutzer 'pi'..."
    echo 'pi:$6$6jHfJHIEiGiMbJxs$LbNesgEJUc2pqwWKzH5uHAywwbEsjB0N2GtPp15zf0JvbadKdJBBrR18Fm58DTaBoYt0GYJnEBjAK7qoBnIWQ/' > "${BOOT_MOUNT}/userconf.txt" || warning "Konnte userconf.txt nicht erstellen."
    
    # Hostname setzen
    info "Setze Hostname: $HOSTNAME..."
    echo "$HOSTNAME" > "${BOOT_MOUNT}/hostname" || warning "Konnte hostname-Datei nicht erstellen."
    
    # SSH-Schlüssel für den Pi-Benutzer einrichten
    if [ -f "$SSH_PUBKEY" ]; then
        info "Konfiguriere SSH-Schlüssel..."
        mkdir -p "${BOOT_MOUNT}/home/pi/.ssh"
        cp "$SSH_PUBKEY" "${BOOT_MOUNT}/home/pi/.ssh/authorized_keys" || warning "Konnte SSH-Schlüssel nicht kopieren."
    else
        warning "SSH-Schlüssel nicht gefunden: $SSH_PUBKEY"
    fi
    
    # USB-Boot-Skript kopieren
    if [ -f "$SETUP_USB_SCRIPT" ]; then
        info "Kopiere USB-Setup-Skript..."
        mkdir -p "${BOOT_MOUNT}/home/pi/scripts"
        cp "$SETUP_USB_SCRIPT" "${BOOT_MOUNT}/home/pi/scripts/" || warning "Konnte USB-Setup-Skript nicht kopieren."
        chmod +x "${BOOT_MOUNT}/home/pi/scripts/$(basename "$SETUP_USB_SCRIPT")" || warning "Konnte Berechtigungen für USB-Setup-Skript nicht setzen."
    else
        warning "USB-Setup-Skript nicht gefunden: $SETUP_USB_SCRIPT"
    fi
    
    success "SD-Karte erfolgreich konfiguriert."
}

# SD-Karte abschließend unmounten
unmount_sd_card() {
    info "Unmounte SD-Karte..."
    
    if [ "$(uname)" == "Darwin" ]; then
        # macOS
        diskutil eject "$BOOT_MOUNT" || warning "Konnte SD-Karte nicht auswerfen."
    else
        # Linux
        umount "$BOOT_MOUNT" || warning "Konnte SD-Karte nicht unmounten."
    fi
    
    success "SD-Karte erfolgreich ausgeworfen."
}

# Anweisungen zum Abschluss
show_final_instructions() {
    echo ""
    echo "======================= FERTIG ======================="
    echo "Die SD-Karte wurde erfolgreich vorbereitet und konfiguriert."
    echo ""
    echo "Nächste Schritte:"
    echo "1. Legen Sie die SD-Karte in Ihren Raspberry Pi ein"
    echo "2. Schließen Sie die USB-Festplatte an"
    echo "3. Verbinden Sie den Pi mit Strom und Netzwerk"
    echo "4. Warten Sie ca. 1-2 Minuten, bis der Pi gestartet ist"
    echo ""
    
    if [ -n "$WIFI_SSID" ]; then
        echo "Der Pi wird sich mit dem WLAN '$WIFI_SSID' verbinden"
    else
        echo "Stellen Sie sicher, dass der Pi mit einem Netzwerkkabel verbunden ist"
    fi
    
    echo ""
    echo "Um sich mit dem Pi zu verbinden:"
    echo "  ssh pi@$HOSTNAME.local"
    echo "  oder"
    echo "  ssh pi@<IP-Adresse>"
    echo ""
    echo "Das Standardpasswort ist: raspberry"
    echo "WICHTIG: Ändern Sie das Passwort nach dem ersten Login mit 'passwd'"
    echo ""
    echo "Um die USB-Festplatte einzurichten, führen Sie auf dem Pi aus:"
    echo "  sudo ~/scripts/$(basename "$SETUP_USB_SCRIPT")"
    echo ""
    echo "Viel Erfolg mit Ihrem Raspberry Pi!"
    echo "=================================================="
}

# Hauptfunktion
main() {
    get_config_details
    check_requirements
    download_os
    select_sd_card
    flash_sd_card
    mount_sd_card
    configure_sd_card
    unmount_sd_card
    show_final_instructions
}

# Ausführen des Hauptprogramms
main
