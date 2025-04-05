#!/bin/bash

# Skript zur Installation von Coolify auf einem Raspberry Pi via SSH
# Setzt eine funktionierende Node.js Umgebung (via pi_setup_nodejs_env.sh)
# und Docker voraus und ist für Cloudflare Tunnel optimiert.
# Nutzt user_input.sh und error_handler.sh

# --- Pfade zu Hilfsskripten ---
# Annahme: Dieses Skript liegt in 'pi/', user_input.sh in 'user/', error_handler.sh in 'misc/'
SCRIPT_DIR_RELATIVE_PATH=$(dirname "$0")
USER_INPUT_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../user/user_input.sh"
ERROR_HANDLER_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../misc/error_handler.sh"

# --- Error Handler einbinden und initialisieren ---
if [[ ! -f "$ERROR_HANDLER_SCRIPT" ]]; then
    echo -e "\033[0;31mFehler: Das Skript 'error_handler.sh' wurde nicht unter '$ERROR_HANDLER_SCRIPT' gefunden.\033[0m" >&2
    echo -e "Bitte stelle sicher, dass 'error_handler.sh' im Verzeichnis '../misc' relativ zu diesem Skript liegt." >&2
    exit 1
fi
# DEBUG=1 # Optional: Debugging für error_handler aktivieren
source "$ERROR_HANDLER_SCRIPT" || { echo -e "\033[0;31mFehler: Konnte 'error_handler.sh' nicht sourcen.\033[0m" >&2; exit 1; }
setup_error_handling # Aktiviert set -e, trap etc. und Logging-Funktionen (log_info, log_error...)

# --- User Input Funktionen einbinden ---
if [[ ! -f "$USER_INPUT_SCRIPT" ]]; then
    log_fatal "Das Skript 'user_input.sh' wurde nicht unter '$USER_INPUT_SCRIPT' gefunden."
fi
source "$USER_INPUT_SCRIPT" || log_fatal "Konnte 'user_input.sh' nicht sourcen."

# --- Banner ---
echo "============================================="
echo "   Raspberry Pi Coolify Deployment           "
echo "   (Für Cloudflare Tunnel Integration)       "
echo "============================================="
echo ""
log_info "Dieses Skript installiert Coolify auf einem entfernten Raspberry Pi via SSH."
log_info "Es wird davon ausgegangen, dass Docker und Node.js bereits eingerichtet sind"
log_info "und der externe Zugriff über einen Cloudflare Tunnel erfolgt."
echo ""

# --- Lokale Konfiguration & Benutzereingaben ---
LOCAL_USER=$(get_user_input "Geben Sie den Benutzernamen für den lokalen SSH-Schlüssel ein" "$(whoami)" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_KEY="/Users/$LOCAL_USER/.ssh/id_rsa_coolify_temp" # Pfad zum SSH Private Key (LOKAL)
log_info "Verwende SSH Key: $SSH_KEY"

PI_HOST=$(get_user_input "Geben Sie die IP-Adresse oder den Hostnamen des Raspberry Pi ein" "192.168.178.40" is_valid_ip_or_hostname "Ungültige IP-Adresse oder Hostname.") || exit 1
PI_USER=$(get_user_input "Geben Sie den SSH-Benutzernamen für den Raspberry Pi ein" "pi" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_PORT=$(get_user_input "Geben Sie den SSH-Port ein" "22" is_valid_port "Ungültiger Port. Bitte eine Zahl zwischen 1 und 65535 eingeben.") || exit 1

# Port, auf dem Coolify später lauschen wird (wichtig für den Cloudflare Tunnel)
COOLIFY_PORT=$(get_user_input "Auf welchem Port soll Coolify auf dem Pi laufen (Standard: 3000)?" "3000" is_valid_port "Ungültiger Port.") || exit 1
log_info "Der Cloudflare Tunnel sollte auf http://localhost:$COOLIFY_PORT auf dem Pi zeigen."
echo ""

# --- SSH-Verbindung testen (LOKAL) ---
log_info "Teste SSH-Verbindung zu $PI_USER@$PI_HOST:$SSH_PORT..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    # Hier wird nach der Passphrase gefragt, wenn nötig
    log_fatal "SSH-Verbindung fehlgeschlagen. Prüfe IP/Hostname ($PI_HOST), Benutzer ($PI_USER), Port ($SSH_PORT), SSH-Schlüssel ($SSH_KEY) und Passphrase."
fi
log_info "SSH-Verbindung erfolgreich."
echo ""

# --- Remote-Ausführung auf dem Raspberry Pi ---
log_info "Starte Coolify Installation auf dem Raspberry Pi ($PI_USER@$PI_HOST)..."
log_warn "Stelle sicher, dass Docker und Node.js bereits installiert sind und der Benutzer '$PI_USER' zur Docker-Gruppe gehört (ggf. neu einloggen)."
log_warn "Die Installation erfordert sudo-Rechte auf dem Pi."
log_info "Die Installation kann einige Minuten dauern..."


# Temporär 'set -u' lokal deaktivieren
set +u
log_info "Temporär 'set -u' deaktiviert für den SSH-Block."

ssh -i "$SSH_KEY" -p "$SSH_PORT" -t "$PI_USER@$PI_HOST" << EOF || log_fatal "Fehler bei der Remote-Ausführung auf dem Pi (SSH-Verbindung getrennt oder Remote-Skript fehlgeschlagen)."
    # --- Anfang des Heredoc ---
    set -e # Beende bei Fehlern im Remote-Skript

    # --- Remote Hilfsfunktionen ---
    R_info() { echo -e "\e[34mInfo (Pi):\e[0m \$1"; }
    R_success() { echo -e "\e[32mErfolg (Pi):\e[0m \$1"; }
    R_warning() { echo -e "\e[33mWarnung (Pi):\e[0m \$1"; }
    R_error() { echo -e "\e[31mFehler (Pi):\e[0m \$1" >&2; exit 1; }

    R_info "*** (Remote Ausführung: Coolify Install) ***"
    echo "============================================="

    # 1. Voraussetzungen prüfen (optional, aber empfohlen)
    R_info "Prüfe Voraussetzungen (Docker, Docker Compose, Git, Curl)..."
    if ! command -v docker &> /dev/null; then
        R_error "Docker scheint nicht installiert zu sein. Bitte zuerst Docker installieren (z.B. mit pi_setup_nodejs_env.sh oder manuell)."
    else
        R_success "Docker gefunden."
        docker --version
    fi
    if ! docker compose version &> /dev/null; then
         R_warning "Docker Compose Plugin ('docker compose') nicht gefunden. Coolify könnte Probleme haben."
         # Optional: Versuch der Installation
         # R_info "Versuche Docker Compose Plugin zu installieren..."
         # sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin || R_warning "Installation fehlgeschlagen."
         # if ! docker compose version &> /dev/null; then R_error "Docker Compose Plugin konnte nicht installiert werden."; fi
    else
         R_success "Docker Compose Plugin gefunden."
         docker compose version
    fi
     if ! command -v git &> /dev/null; then
        R_warning "Git nicht gefunden. Wird für Builds benötigt. Installiere..."
        sudo apt-get update -y && sudo apt-get install -y git || R_error "Git konnte nicht installiert werden."
        R_success "Git installiert."
    else
        R_success "Git gefunden."
    fi
     if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
         R_error "Weder curl noch wget gefunden. Wird zum Herunterladen benötigt."
    else
        R_success "curl/wget gefunden."
    fi
    # Wichtige Prüfung: Docker-Gruppe
     if ! groups \$USER | grep -q '\bdocker\b'; then
        R_error "Benutzer '\$USER' ist NICHT in der Docker-Gruppe! Coolify benötigt dies. Bitte führe 'sudo usermod -aG docker \$USER' aus, logge dich aus und wieder ein und starte das Skript erneut."
    else
        R_success "Benutzer '\$USER' ist in der Docker-Gruppe."
    fi
    echo ""


    # 2. Coolify Installation
    R_info "Installiere/Update Coolify..."
    COOLIFY_INSTALL_DIR="/data/coolify" # Standard-Installationsverzeichnis

    if [ -d "\$COOLIFY_INSTALL_DIR" ]; then
        R_warning "Coolify-Verzeichnis (\$COOLIFY_INSTALL_DIR) existiert bereits. Das Skript wird versuchen, Coolify zu aktualisieren."
    fi

    R_info "Lade Coolify Installations-/Update-Skript herunter..."
    cd /tmp || cd \$HOME
    # Versuche wget, fallback auf curl
    if command -v curl &> /dev/null; then
        curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash|| R_error "Download des Coolify-Skripts mit wget fehlgeschlagen."
    elif command -v curl &> /dev/null; then
        curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash || R_error "Download des Coolify-Skripts mit curl fehlgeschlagen."
    else
         R_error "Weder wget noch curl zum Download verfügbar." # Sollte durch Check oben nicht passieren
    fi

    R_info "Setze Port für Coolify auf $COOLIFY_PORT..."
    # Coolify-Skript via Umgebungsvariable konfigurieren
    export COOLIFY_APP_PORT=$COOLIFY_PORT

    R_info "Führe Coolify Installations-/Update-Skript aus (mit sudo)..."
    # Das Skript benötigt sudo-Rechte
    sudo bash coolify.sh || R_error "Ausführung des Coolify-Skripts fehlgeschlagen."

    # Bereinigen
    rm -f coolify.sh

    R_success "Coolify Installation/Update abgeschlossen."
    R_info "Coolify sollte unter Port $COOLIFY_PORT auf dem Pi verfügbar sein."
    R_info "Der externe Zugriff erfolgt über deinen separat konfigurierten Cloudflare Tunnel!"

    echo "============================================="
    R_success "Coolify Setup auf Pi abgeschlossen!"
    R_info "*** (Remote-Ausführung beendet) ***"
EOF
# --- Ende des Heredoc ---
SSH_EXIT_CODE=$? # Exit-Code direkt nach dem SSH-Befehl speichern

# 'set -u' wieder aktivieren für den Rest des lokalen Skripts
set -u
log_info "'set -u' wieder aktiviert."

# Exit-Status des SSH-Befehls prüfen
if [ $SSH_EXIT_CODE -ne 0 ]; then
    log_error "SSH-Befehl wurde mit Exit Code $SSH_EXIT_CODE beendet (Fehler wurde evtl. schon durch log_fatal gemeldet)."
    exit $SSH_EXIT_CODE # Beende das lokale Skript bei Fehler im Remote-Teil
fi

echo ""
log_info "------------------------------------------------------------------"
log_success "Coolify Deployment Skript erfolgreich abgeschlossen!"
log_info "Coolify wurde auf dem Pi installiert/aktualisiert und sollte auf Port $COOLIFY_PORT laufen."
log_warn "Falls der Benutzer '$PI_USER' auf dem Pi neu zur Docker-Gruppe hinzugefügt wurde, ist ein Neustart des Pi oder zumindest ein erneutes Einloggen erforderlich!"
log_info "Stelle sicher, dass dein Cloudflare Tunnel korrekt auf 'http://localhost:$COOLIFY_PORT' auf dem Pi zeigt."
log_info "Du solltest Coolify nun über die im Tunnel konfigurierte Domain erreichen können."
log_info "------------------------------------------------------------------"

exit 0