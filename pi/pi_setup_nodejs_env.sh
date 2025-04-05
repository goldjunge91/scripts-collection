#!/bin/bash

# Skript zur Einrichtung einer Node.js Entwicklungsumgebung auf einem Raspberry Pi
# Installiert: Zsh, NVM, Node.js (LTS), PNPM (via Corepack), PM2 (global)
# Nutzt user_input.sh und error_handler.sh

# --- Pfade zu Hilfsskripten ---
# Annahme: Dieses Skript liegt in 'pi/', user_input.sh in 'user/', error_handler.sh in 'misc/'
SCRIPT_DIR_RELATIVE_PATH=$(dirname "$0")
USER_INPUT_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../user/user_input.sh"
ERROR_HANDLER_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../misc/error_handler.sh"

# --- Error Handler einbinden und initialisieren ---
if [[ ! -f "$ERROR_HANDLER_SCRIPT" ]]; then
    echo -e "\033[0;31mFehler: Das Skript 'error_handler.sh' wurde nicht unter '$ERROR_HANDLER_SCRIPT' gefunden.\033[0m" >&2
    echo -e "Bitte stelle sicher, dass 'error_handler.sh' im Verzeichnis '$ERROR_HANDLER_SCRIPT' relativ zu diesem Skript liegt." >&2
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
echo "   Raspberry Pi Node.js Environment Setup    "
echo "   (Zsh, NVM, Node, PNPM, PM2)             "
echo "============================================="
echo ""
log_info "Dieses Skript installiert eine Node.js Entwicklungsumgebung auf einem entfernten Raspberry Pi via SSH."
echo ""

# --- Lokale Konfiguration & Benutzereingaben ---
LOCAL_USER=$(get_user_input "Geben Sie den Benutzernamen für den lokalen SSH-Schlüssel ein" "$(whoami)" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_KEY="/Users/$LOCAL_USER/.ssh/id_rsa_pi_colify" # Pfad zum SSH Private Key (LOKAL)
log_info "Verwende SSH Key: $SSH_KEY"

PI_HOST=$(get_user_input "Geben Sie die IP-Adresse oder den Hostnamen des Raspberry Pi ein" "192.168.178.40" is_valid_ip_or_hostname "Ungültige IP-Adresse oder Hostname.") || exit 1
PI_USER=$(get_user_input "Geben Sie den SSH-Benutzernamen für den Raspberry Pi ein" "pi" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_PORT=$(get_user_input "Geben Sie den SSH-Port ein" "22" is_valid_port "Ungültiger Port. Bitte eine Zahl zwischen 1 und 65535 eingeben.") || exit 1
echo ""

# --- SSH-Verbindung testen (LOKAL) ---
log_info "Teste SSH-Verbindung zu $PI_USER@$PI_HOST:$SSH_PORT..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    log_fatal "SSH-Verbindung fehlgeschlagen. Prüfe IP/Hostname ($PI_HOST), Benutzer ($PI_USER), Port ($SSH_PORT) und SSH-Schlüssel ($SSH_KEY)."
fi
log_info "SSH-Verbindung erfolgreich."
echo ""

# --- Remote-Ausführung auf dem Raspberry Pi ---
log_info "Starte Node.js Environment Setup auf dem Raspberry Pi ($PI_USER@$PI_HOST)..."
log_warn "Einige Schritte erfordern sudo-Passworteingabe auf dem Pi oder sudo ohne Passwort."

ssh -i "$SSH_KEY" -p "$SSH_PORT" -t "$PI_USER@$PI_HOST" << EOF || log_fatal "Fehler bei der Remote-Ausführung auf dem Pi (SSH-Verbindung getrennt?)."
    # Führe alle folgenden Befehle auf dem Pi aus
    set -e # Beende bei Fehlern im Remote-Skript

    # --- Remote Hilfsfunktionen ---
    R_info() { echo -e "\e[34mInfo (Pi):\e[0m \$1"; }
    R_success() { echo -e "\e[32mErfolg (Pi):\e[0m \$1"; }
    R_warning() { echo -e "\e[33mWarnung (Pi):\e[0m \$1"; }
    R_error() { echo -e "\e[31mFehler (Pi):\e[0m \$1" >&2; exit 1; }

    R_info "*** (Remote-Ausführung auf \$HOSTNAME als \$USER) ***"
    echo "============================================="

    # 1. System-Update und Basispakete installieren
    R_info "Aktualisiere Paketlisten und installiere Basispakete (curl, git, zsh, build-essential)..."
    sudo apt-get update -y || R_warning "apt update fehlgeschlagen, versuche trotzdem fortzufahren."
    sudo apt-get install -y curl git zsh build-essential || R_error "Installation der Basispakete fehlgeschlagen."
    R_success "Basispakete installiert."
    echo ""

    # 2. NVM (Node Version Manager) installieren
    R_info "Installiere NVM..."
    # Lade und führe das NVM Installationsskript aus
    export NVM_DIR="\$HOME/.nvm" # Exportiere für das Installationsskript
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || R_error "NVM Installation fehlgeschlagen."
    R_success "NVM heruntergeladen und Installationsskript ausgeführt."

    # NVM für die AKTUELLE Shell-Sitzung laden (wichtig für folgende Befehle)
    # Diese Zeilen müssen genau so im Skript stehen, damit NVM geladen wird
    R_info "Lade NVM in die aktuelle Shell-Sitzung..."
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    [ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
    # Überprüfen, ob nvm jetzt verfügbar ist
    if ! command -v nvm &> /dev/null; then
        R_error "NVM konnte nicht in die aktuelle Shell geladen werden!"
    fi
    R_success "NVM in aktueller Shell verfügbar."
    echo ""

    # 3. NVM Konfiguration für zukünftige Logins (.bashrc, .zshrc)
    R_info "Konfiguriere Shells (.bashrc, .zshrc), um NVM bei neuen Logins zu laden..."
    NVM_CONFIG_SNIPPET='
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion'

    # Für .bashrc
    if [ -f "\$HOME/.bashrc" ]; then
        if ! grep -q 'NVM_DIR' "\$HOME/.bashrc"; then
            R_info "Füge NVM Konfiguration zu \$HOME/.bashrc hinzu."
            echo "$NVM_CONFIG_SNIPPET" >> "\$HOME/.bashrc"
        else
            R_info "NVM Konfiguration scheint bereits in \$HOME/.bashrc zu existieren."
        fi
    else
         R_warning "\$HOME/.bashrc nicht gefunden."
    fi

    # Für .zshrc
    if [ -f "\$HOME/.zshrc" ]; then
        if ! grep -q 'NVM_DIR' "\$HOME/.zshrc"; then
            R_info "Füge NVM Konfiguration zu \$HOME/.zshrc hinzu."
            echo "$NVM_CONFIG_SNIPPET" >> "\$HOME/.zshrc"
        else
            R_info "NVM Konfiguration scheint bereits in \$HOME/.zshrc zu existieren."
        fi
    else
        R_info "Erstelle \$HOME/.zshrc und füge NVM Konfiguration hinzu."
        echo "$NVM_CONFIG_SNIPPET" >> "\$HOME/.zshrc"
    fi
    R_success "Shell-Konfiguration für NVM abgeschlossen."
    echo ""

    # 4. Node.js (LTS) installieren
    R_info "Installiere die neueste Node.js LTS Version via NVM..."
    # Lädt nvm (falls noch nicht geschehen, sicherheitshalber)
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    nvm install --lts || R_error "Installation von Node.js LTS fehlgeschlagen."
    # Setze die installierte LTS-Version als Standard
    nvm alias default lts/* || R_warning "Konnte default NVM Alias nicht setzen."
    # Verwende die LTS-Version in der aktuellen Sitzung
    nvm use default || R_error "Konnte die installierte Node.js Version nicht aktivieren."
    R_success "Node.js LTS installiert und als Standard gesetzt."
    node -v || R_warning "Konnte Node Version nicht anzeigen."
    npm -v || R_warning "Konnte NPM Version nicht anzeigen."
    echo ""

    # 5. Corepack aktivieren und PNPM installieren
    R_info "Aktiviere Corepack..."
    corepack enable || R_error "Corepack konnte nicht aktiviert werden."
    R_success "Corepack aktiviert."
    R_info "Installiere die neueste PNPM Version via Corepack..."
    corepack prepare pnpm@latest --activate || R_error "PNPM Installation via Corepack fehlgeschlagen."
    R_success "PNPM installiert."
    pnpm -v || R_warning "Konnte PNPM Version nicht anzeigen."
    echo ""

    # 6. PM2 global installieren
    R_info "Installiere PM2 global via NPM..."
    # Sicherstellen, dass npm aus dem NVM Pfad verwendet wird
    npm install pm2 -g || R_error "PM2 Installation fehlgeschlagen."
    R_success "PM2 global installiert."
    # Versuchen, den Pfad für global installierte Pakete zu finden und PM2 zu testen
    if command -v pm2 &> /dev/null; then
        pm2 -v || R_warning "Konnte PM2 Version nicht anzeigen."
    else
        R_warning "PM2 Befehl nicht im PATH gefunden. Möglicherweise ist eine Neuanmeldung nötig oder der NVM/NPM Pfad muss manuell zum PATH hinzugefügt werden."
    fi
    echo ""

    # 7. Abschlussprüfung (Zusammenfassung)
    R_info "Überprüfung der installierten Versionen:"
    echo -n "Zsh: "; zsh --version || echo "Nicht gefunden"
    echo -n "NVM: "; nvm --version || echo "Nicht gefunden"
    echo -n "Node: "; node -v || echo "Nicht gefunden"
    echo -n "NPM: "; npm -v || echo "Nicht gefunden"
    echo -n "PNPM: "; pnpm -v || echo "Nicht gefunden"
    echo -n "PM2: "; if command -v pm2 &> /dev/null; then pm2 -v; else echo "Nicht im PATH gefunden"; fi
    echo ""


    echo "============================================="
    R_success "Node.js Environment Setup auf Pi abgeschlossen!"
    R_warning "WICHTIG: Für NVM und global installierte NPM Pakete (wie PM2) ist möglicherweise eine Neuanmeldung (ausloggen und wieder einloggen via SSH) erforderlich, damit sie in neuen Shell-Sitzungen korrekt im PATH gefunden werden."
    R_info "Um Zsh als Standard-Shell festzulegen (optional), führe nach dem erneuten Login aus: chsh -s \$(which zsh)"
    R_info "*** (Remote-Ausführung auf Pi beendet) ***"

EOF

# Exit-Status des SSH-Befehls prüfen (wird durch log_fatal oben behandelt, falls SSH selbst fehlschlägt)
SSH_EXIT_CODE=$?
if [ $SSH_EXIT_CODE -ne 0 ]; then
     log_error "SSH-Befehl wurde unerwartet beendet (Exit Code: $SSH_EXIT_CODE). Prüfe die Remote-Logs oben."
     exit $SSH_EXIT_CODE
fi

echo ""
log_info "------------------------------------------------------------------"
log_success "Gesamtes Skript zur Einrichtung der Node.js Umgebung abgeschlossen!"
log_warn "Denke daran, dich auf dem Pi neu einzuloggen, damit alle PATH-Änderungen (NVM, PM2) wirksam werden."
log_info "------------------------------------------------------------------"

exit 0