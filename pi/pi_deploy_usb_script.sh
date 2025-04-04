#!/bin/bash

# Raspberry Pi USB-Setup Deployment Skript
# Dieses Skript überträgt das USB-Festplatten-Setup-Skript auf einen Raspberry Pi
# und führt es automatisch per SSH aus.
# Es verwendet dabei den SSH-Schlüssel id_rsa_pi_colify

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Funktion: Fehler und Exit
error() {
    echo -e "${RED}Fehler: $1${NC}" >&2
    exit 1
}

# Standardpfad zum USB-Setup-Skript
USB_SETUP_SCRIPT="/Users/marco/scripts-collection/pi/pi_usb_drive_setup.sh"

# Standardpfad zum SSH-Schlüssel
SSH_KEY="/Users/marco/.ssh/id_rsa_pi_colify"

# Banner anzeigen
echo "============================================="
echo "Raspberry Pi USB-Setup Deployment Tool"
echo "============================================="
echo ""

# Prüfen, ob das USB-Setup-Skript existiert
if [ ! -f "$USB_SETUP_SCRIPT" ]; then
    error "USB-Setup-Skript nicht gefunden: $USB_SETUP_SCRIPT"
fi

# IP-Adresse oder Hostname des Raspberry Pi abfragen
read -p "Geben Sie die IP-Adresse oder den Hostnamen des Raspberry Pi ein: " PI_HOST
if [ -z "$PI_HOST" ]; then
    error "Keine IP-Adresse oder Hostname angegeben."
fi

# Benutzername abfragen (Standard: pi)
read -p "Geben Sie den Benutzernamen ein [pi]: " PI_USER
PI_USER=${PI_USER:-pi}

# SSH-Port abfragen (Standard: 22)
read -p "Geben Sie den SSH-Port ein [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# SSH-Zielverzeichnis abfragen (Standard: /home/USERNAME)
read -p "Zielverzeichnis auf dem Raspberry Pi [/home/$PI_USER]: " TARGET_DIR
TARGET_DIR=${TARGET_DIR:-/home/$PI_USER}

# SSH-Verbindung testen
info "Teste SSH-Verbindung zu $PI_USER@$PI_HOST:$SSH_PORT mit Schlüssel $SSH_KEY..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    warning "SSH-Verbindungstest fehlgeschlagen. Versuche trotzdem fortzufahren..."
fi

# Dateinamen des Skripts extrahieren
SCRIPT_FILENAME=$(basename "$USB_SETUP_SCRIPT")

# Skript auf den Raspberry Pi übertragen
info "Übertrage USB-Setup-Skript auf den Raspberry Pi..."
if ! scp -i "$SSH_KEY" -P $SSH_PORT "$USB_SETUP_SCRIPT" "$PI_USER@$PI_HOST:$TARGET_DIR/"; then
    error "Übertragung des Skripts fehlgeschlagen."
fi
success "Skript erfolgreich übertragen."

# Skript ausführbar machen
info "Mache Skript ausführbar..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "chmod +x $TARGET_DIR/$SCRIPT_FILENAME"; then
    error "Konnte Skript nicht ausführbar machen."
fi
success "Skript ist jetzt ausführbar."

# Nachfragen, ob das Skript ausgeführt werden soll
read -p "Möchten Sie das USB-Setup-Skript jetzt auf dem Raspberry Pi ausführen? (j/n): " RUN_SCRIPT
if [ "$RUN_SCRIPT" = "j" ] || [ "$RUN_SCRIPT" = "J" ]; then
    info "Führe USB-Setup-Skript auf dem Raspberry Pi aus..."
    echo "Dies kann einige Zeit dauern. Bitte warten..."
    echo ""
    echo "============= Skriptausführung auf dem Raspberry Pi ============="
    ssh -i "$SSH_KEY" -t -p $SSH_PORT $PI_USER@$PI_HOST "sudo $TARGET_DIR/$SCRIPT_FILENAME"
    echo "================================================================="
    
    # Überprüfen des Ausführungsstatus
    if [ $? -eq 0 ]; then
        success "USB-Setup-Skript wurde erfolgreich ausgeführt."
    else
        warning "Bei der Ausführung des USB-Setup-Skripts sind möglicherweise Fehler aufgetreten."
    fi
else
    info "Skriptausführung übersprungen."
    echo ""
    echo "Um das Skript später manuell auszuführen, verbinden Sie sich mit dem Raspberry Pi und führen Sie aus:"
    echo "  ssh -i $SSH_KEY $PI_USER@$PI_HOST -p $SSH_PORT"
    echo "  sudo $TARGET_DIR/$SCRIPT_FILENAME"
fi

echo ""
echo "============================================="
echo "Deployment abgeschlossen!"
echo "============================================="
