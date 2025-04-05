#!/bin/bash

# Skript zur Einrichtung eines Cloudflare Tunnels (cloudflared)
# auf einem entfernten Raspberry Pi via SSH
# Nutzt user_input.sh für verbesserte Eingaben

# --- Pfad zum user_input Skript ---
# Annahme: user_input.sh liegt im Verzeichnis ../user relativ zu diesem Skript
SCRIPT_DIR_RELATIVE_PATH=$(dirname "$0") # Verzeichnis dieses Skripts
USER_INPUT_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../user/user_input.sh"

# Prüfen und Source der Eingabe-Funktionen
if [[ ! -f "$USER_INPUT_SCRIPT" ]]; then
    echo -e "\033[0;31mFehler: Das Skript 'user_input.sh' wurde nicht unter '$USER_INPUT_SCRIPT' gefunden.\033[0m" >&2
    echo -e "Bitte stelle sicher, dass 'user_input.sh' im Verzeichnis '../user' relativ zu diesem Skript liegt." >&2
    exit 1
fi
source "$USER_INPUT_SCRIPT" || { echo -e "\033[0;31mFehler: Konnte 'user_input.sh' nicht sourcen.\033[0m" >&2; exit 1; }

# --- Farben für Ausgaben (werden auch von user_input.sh genutzt) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Hilfsfunktionen (überschreiben evtl. die aus user_input, falls dort vorhanden) ---
info() { echo -e "${BLUE}Info: $1${NC}"; }
success() { echo -e "${GREEN}Erfolg: $1${NC}"; }
warning() { echo -e "${YELLOW}Warnung: $1${NC}"; }
error() { echo -e "${RED}Fehler: $1${NC}" >&2; exit 1; }

# --- Banner ---
echo "============================================="
echo "  Cloudflare Tunnel (cloudflared) Setup      "
echo "       via SSH auf Raspberry Pi              "
echo "============================================="
echo ""

# --- Lokale Konfiguration & Benutzereingaben ---
LOCAL_USER=$(get_user_input "Geben Sie den Benutzernamen für den lokalen SSH-Schlüssel ein" "$(whoami)" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_KEY="/Users/$LOCAL_USER/.ssh/id_rsa_pi_colify" # Pfad zum SSH Private Key (LOKAL)
info "Verwende SSH Key: $SSH_KEY"

PI_HOST=$(get_user_input "Geben Sie die IP-Adresse oder den Hostnamen des Raspberry Pi ein" "192.168.178.40" is_valid_ip_or_hostname "Ungültige IP-Adresse oder Hostname.") || exit 1
PI_USER=$(get_user_input "Geben Sie den SSH-Benutzernamen für den Raspberry Pi ein" "pi" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
SSH_PORT=$(get_user_input "Geben Sie den SSH-Port ein" "22" is_valid_port "Ungültiger Port. Bitte eine Zahl zwischen 1 und 65535 eingeben.") || exit 1

TUNNEL_NAME=$(get_user_input "Gib einen Namen für den neuen Tunnel ein (z.B. 'pi-zuhause')" "pi-tunnel" is_not_empty "Kein Tunnel-Name angegeben.") || exit 1
HOSTNAME_TO_ROUTE=$(get_user_input "Welcher Hostname soll auf den Tunnel zeigen? (z.B. tozzi-test.de)" "tozzi-test.de" is_valid_hostname "Ungültiger Hostname oder leere Eingabe.") || exit 1
INTERNAL_SERVICE_URL_DEFAULT="http://localhost:3000" # Z.B. Port, auf dem Caddy oder ein anderer Webserver auf dem Pi lauscht
INTERNAL_SERVICE_URL=$(get_user_input "Welche lokale Service-URL soll '$HOSTNAME_TO_ROUTE' aufrufen?" "$INTERNAL_SERVICE_URL_DEFAULT" is_not_empty "Leere Eingabe ist nicht erlaubt.") || exit 1
echo ""

# --- SSH-Verbindung testen (LOKAL) ---
info "Teste SSH-Verbindung zu $PI_USER@$PI_HOST:$SSH_PORT..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    error "SSH-Verbindung fehlgeschlagen. Prüfe IP/Hostname, Benutzer ($PI_USER), Port ($SSH_PORT) und SSH-Schlüssel ($SSH_KEY)."
fi
success "SSH-Verbindung erfolgreich."
echo ""

# --- Remote-Ausführung auf dem Raspberry Pi ---
info "Starte Setup-Prozess auf dem Raspberry Pi ($PI_USER@$PI_HOST)..."
warning "Einige Schritte erfordern sudo-Passworteingabe auf dem Pi oder sudo ohne Passwort."

# Verwende 'EOF' ohne Anführungszeichen, damit lokale Variablen wie $TUNNEL_NAME expandiert werden.
# Vorsicht bei $-Zeichen innerhalb des Blocks, die nicht expandiert werden sollen (ggf. escapen: \$)
ssh -i "$SSH_KEY" -p "$SSH_PORT" -t "$PI_USER@$PI_HOST" << EOF || error "Fehler bei der Remote-Ausführung auf dem Pi."
    # Führe alle folgenden Befehle auf dem Pi aus

    # --- WICHTIG: 'set -e' und 'trap ERR' ENTFERNT ---

    # --- Hilfsfunktionen für Remote ---
    R_info() { echo -e "\e[34mInfo (Pi):\e[0m \$1"; }
    R_success() { echo -e "\e[32mErfolg (Pi):\e[0m \$1"; }
    R_warning() { echo -e "\e[33mWarnung (Pi):\e[0m \$1"; }
    # R_error MUSS weiterhin exit aufrufen!
    R_error() { echo -e "\e[31mFehler (Pi):\e[0m \$1" >&2; exit 1; }

    # Funktion für nicht-kritische Fehler
    handle_non_critical_error() {
        local exit_code=\$? # Muss die erste Zeile sein!
        local message="\$1"
        R_warning "Ein nicht-kritischer Fehler ist aufgetreten (Exit Code: \$exit_code): \$message. Skript wird fortgesetzt."
        return 0 # Wichtig: Gibt Erfolg zurück, damit das Skript weiterläuft
    }

    R_info "Starte cloudflared Setup auf dem Pi..."
    echo "============================================="

    # --- 1. cloudflared Installation ---
    R_info "Installiere/Update cloudflared..."
    # Architektur prüfen
    ARCH=\$(dpkg --print-architecture) || R_error "Architektur konnte nicht ermittelt werden."
    if [ "\$ARCH" = "arm64" ]; then
      DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
    elif [ "\$ARCH" = "armhf" ] || [ "\$ARCH" = "armel" ]; then
      DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.deb"
    else
      R_error "Nicht unterstützte Architektur auf dem Pi: \$ARCH"
    fi
    TEMP_DEB="/tmp/cloudflared.deb"
    R_info "Lade \$DEB_URL herunter..."
    curl -Lsf "\$DEB_URL" -o "\$TEMP_DEB" || R_error "Download von cloudflared fehlgeschlagen. (URL: \$DEB_URL)"
    R_info "Installiere Paket mit sudo..."
    sudo dpkg -i "\$TEMP_DEB"
    DPKG_EXIT_CODE=\$?
    if [ \$DPKG_EXIT_CODE -ne 0 ]; then
      R_warning "dpkg-Installation fehlgeschlagen (Code: \$DPKG_EXIT_CODE). Versuche Abhängigkeiten aufzulösen mit sudo..."
      sudo apt-get update || handle_non_critical_error "apt update fehlgeschlagen."
      sudo apt --fix-broken install -y || { rm -f "\$TEMP_DEB"; R_error "Konnte Abhängigkeiten nicht auflösen ('apt --fix-broken install -y' fehlgeschlagen)."; }
      sudo dpkg -i "\$TEMP_DEB" || { rm -f "\$TEMP_DEB"; R_error "Installation von cloudflared endgültig fehlgeschlagen (nach fix-broken)."; }
    fi
    rm -f "\$TEMP_DEB"
    R_success "cloudflared erfolgreich installiert/aktualisiert."
    cloudflared --version || R_warning "cloudflared --version fehlgeschlagen."
    echo ""

    # --- 2. Login bei Cloudflare (nur wenn nötig) ---
    CERT_PATH="\$HOME/.cloudflared/cert.pem"
    if [ -f "\$CERT_PATH" ]; then
        R_success "Vorhandenes Login-Zertifikat gefunden (\$CERT_PATH). Überspringe Login-Schritt."
        echo ""
    else
        R_info "Starte Cloudflare Login-Prozess auf dem Pi."
        R_warning "Du musst den angezeigten Link auf deinem LOKALEN Rechner öffnen!"
        echo "Bitte kopiere die folgende URL, öffne sie in einem Browser auf deinem lokalen Rechner,"
        echo "logge dich ein und wähle die Domain aus, die du verwenden möchtest."
        echo ""
        cloudflared login || R_error "cloudflared login Befehl fehlgeschlagen."
        R_info "Warte auf Cloudflare Login-Bestätigung im Browser und Zertifikat (\$CERT_PATH)..."
        counter=0
        max_retries=24
        sleep_duration=5
        while [ ! -f "\$CERT_PATH" ]; do
            counter=\$((counter + 1))
            if [ "\$counter" -gt "\$max_retries" ]; then
                R_error "Timeout: Zertifikat (\$CERT_PATH) wurde nach \$((max_retries * sleep_duration)) Sekunden nicht gefunden. Login im Browser fehlgeschlagen oder nicht abgeschlossen?"
            fi
            echo -n "."
            sleep \$sleep_duration
        done
        echo ""
        if [ ! -f "\$CERT_PATH" ]; then
             R_error "Konnte Login-Zertifikat trotz Wartezeit nicht finden."
        fi
        R_success "Login-Zertifikat erfolgreich gefunden/erstellt: \$CERT_PATH"
        echo ""
    fi # Ende der if-Bedingung für existierendes Zertifikat


    # --- 3. Tunnel erstellen (als root/sudo, aber mit User-Zertifikat) ---

    # !!! KORREKTUR: Alte Config VOR 'tunnel create' löschen !!!
    R_info "Entferne alte Konfigurationsdatei (falls vorhanden)..."
    CLOUDFLARED_CONFIG_DIR="/etc/cloudflared" # Sicherstellen, dass Verzeichnis definiert ist
    CLOUDFLARED_CONFIG_FILE="\$CLOUDFLARED_CONFIG_DIR/config.yml" # Sicherstellen, dass Variable hier definiert ist
    sudo rm -f "\$CLOUDFLARED_CONFIG_FILE"

    # Jetzt den Tunnel erstellen/überprüfen
    R_info "Erstelle oder überprüfe Tunnel '$TUNNEL_NAME' mit sudo..."
    USER_CERT_PATH="\$HOME/.cloudflared/cert.pem" # Pfad zum Zertifikat des Users

    # Explicitly point sudo command to the user's cert.pem
    # Fange die Ausgabe und den Exit-Code separat auf
    TUNNEL_OUTPUT=\$(sudo cloudflared --origincert "\$USER_CERT_PATH" tunnel create "$TUNNEL_NAME" 2>&1)
    TUNNEL_CREATE_EXIT_CODE=\$?
    echo "\$TUNNEL_OUTPUT" # Ausgabe immer anzeigen für Debugging

    # Tunnel ID initialisieren
    TUNNEL_ID=""

    if [ \$TUNNEL_CREATE_EXIT_CODE -ne 0 ]; then
        # Prüfen, ob der Tunnel vielleicht schon existiert
        if echo "\$TUNNEL_OUTPUT" | grep -q "already exists"; then
            R_success "Tunnel '$TUNNEL_NAME' existiert bereits."
            R_info "Versuche ID des existierenden Tunnels '$TUNNEL_NAME' zu holen..."
            TUNNEL_ID_OUTPUT=\$(cloudflared --origincert "\$USER_CERT_PATH" tunnel list | grep "$TUNNEL_NAME" | awk '{print \$1}') || handle_non_critical_error "Konnte Tunnel-Liste nicht abrufen."
            TUNNEL_ID=\$(echo "\$TUNNEL_ID_OUTPUT" | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
            if [[ -z "\$TUNNEL_ID" ]]; then
                 R_warning "Konnte ID für existierenden Tunnel '$TUNNEL_NAME' nicht automatisch bestimmen. Bitte manuell im Dashboard prüfen oder Tunnel löschen/neu erstellen."
            else
                 R_success "ID für existierenden Tunnel gefunden: \$TUNNEL_ID"
            fi
        else
             # Anderer Fehler beim Erstellen ist wahrscheinlich kritisch
             R_error "Fehler beim Erstellen des Tunnels '$TUNNEL_NAME' (Code: \$TUNNEL_CREATE_EXIT_CODE)."
        fi
    else
         # Erfolgreich neu erstellt, ID extrahieren
         TUNNEL_ID=\$(echo "\$TUNNEL_OUTPUT" | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
         # Annahme: Die .json Credentials Datei wird hier in /home/pi/.cloudflared/ gespeichert, wenn der Tunnel neu erstellt wird
         # Diese müssen wir später evtl. nach /etc/cloudflared kopieren
         R_success "Tunnel '$TUNNEL_NAME' neu erstellt mit ID: \$TUNNEL_ID"
    fi

    # Abbruch, wenn keine Tunnel-ID ermittelt werden konnte
    if [[ -z "\$TUNNEL_ID" ]]; then
        R_error "Konnte keine gültige Tunnel-ID für '$TUNNEL_NAME' ermitteln. Setup kann nicht fortgesetzt werden."
    fi

    R_info "Verwende Tunnel-ID: \$TUNNEL_ID"
    echo ""

    # --- 4. Konfigurationsdatei erstellen (als root/sudo) ---
    R_info "Erstelle/Aktualisiere Konfigurationsdatei /etc/cloudflared/config.yml mit sudo..."
    # Die Variablen CLOUDFLARED_CONFIG_DIR und CLOUDFLARED_CONFIG_FILE wurden bereits in Schritt 3 definiert
    # Die Credentials-Datei wird vom Service erwartet...
    # Konfigurationsverzeichnis erstellen (falls nicht durch rm gelöscht, oder sicherheitshalber)
    sudo mkdir -p "\$CLOUDFLARED_CONFIG_DIR" || R_error "Konnte Verzeichnis \$CLOUDFLARED_CONFIG_DIR nicht erstellen."

    # Pfad zur potentiell neu erstellten Credentials-Datei im Home des Users prüfen
    # Diese wird NICHT mit sudo erstellt, sondern durch den `cloudflared tunnel create` Befehl als normaler User (durch --origincert)
    # ABER: Der Befehl wurde mit sudo ausgeführt. Wo landet die Datei? Laut Log: /home/pi/.cloudflared/<ID>.json
    # Wir MÜSSEN diese Datei für den Service nach /etc/cloudflared kopieren.
    USER_CRED_FILE_PATH="\$HOME/.cloudflared/\${TUNNEL_ID}.json" # Wo `create` sie vermutlich hinlegt (gemäss Log)
    CREDENTIALS_TARGET_PATH="\$CLOUDFLARED_CONFIG_DIR/\$TUNNEL_ID.json" # Ziel für Service

    # Prüfen ob die User-Credentials-Datei existiert
    if [ -f "\$USER_CRED_FILE_PATH" ]; then
        R_info "Kopiere Credentials von \$USER_CRED_FILE_PATH nach \$CREDENTIALS_TARGET_PATH..."
        sudo cp "\$USER_CRED_FILE_PATH" "\$CREDENTIALS_TARGET_PATH" || R_error "Konnte Credentials-Datei nicht kopieren."
        # Besitzer/Rechte für den Service setzen
        if id -u cloudflared >/dev/null 2>&1; then
          sudo chown cloudflared:cloudflared "\$CREDENTIALS_TARGET_PATH" 2>/dev/null || R_warning "Konnte Besitzer der Credentials nicht auf cloudflared setzen."
        else
          sudo chown root:root "\$CREDENTIALS_TARGET_PATH" 2>/dev/null || R_warning "Konnte Besitzer der Credentials nicht auf root setzen."
        fi
        sudo chmod 600 "\$CREDENTIALS_TARGET_PATH" || R_error "Konnte Rechte für Credentials nicht setzen."
        CRED_FILE_LINE="credentials-file: \$CREDENTIALS_TARGET_PATH"
    else
        # Wenn die Datei nicht im User-Home ist, versuchen wir den alten Pfad unter /root/.cloudflared
        # (Falls der Tunnel doch mit reinem sudo erstellt wurde)
        SUDO_CRED_FILE_PATH="/root/.cloudflared/\${TUNNEL_ID}.json"
        if [ -f "\$SUDO_CRED_FILE_PATH" ]; then
           R_info "Kopiere Credentials von \$SUDO_CRED_FILE_PATH nach \$CREDENTIALS_TARGET_PATH..."
           sudo cp "\$SUDO_CRED_FILE_PATH" "\$CREDENTIALS_TARGET_PATH" || R_error "Konnte Credentials-Datei nicht kopieren."
           if id -u cloudflared >/dev/null 2>&1; then
             sudo chown cloudflared:cloudflared "\$CREDENTIALS_TARGET_PATH" 2>/dev/null || R_warning "Konnte Besitzer der Credentials nicht auf cloudflared setzen."
           else
             sudo chown root:root "\$CREDENTIALS_TARGET_PATH" 2>/dev/null || R_warning "Konnte Besitzer der Credentials nicht auf root setzen."
           fi
           sudo chmod 600 "\$CREDENTIALS_TARGET_PATH" || R_error "Konnte Rechte für Credentials nicht setzen."
           CRED_FILE_LINE="credentials-file: \$CREDENTIALS_TARGET_PATH"
        else
           R_warning "Credentials-Datei weder in \$USER_CRED_FILE_PATH noch in \$SUDO_CRED_FILE_PATH gefunden. Config wird ohne erstellt. 'service install' muss Authentifizierung handhaben."
           CRED_FILE_LINE="# credentials-file: Pfad nicht gefunden bei Skriptausführung"
        fi
    fi

   # Jetzt die neue Datei schreiben
     echo "# Cloudflare Tunnel Configuration Generated by Script
 # Tunnel ID to connect to. The tunnel token is usually managed by 'service install'.
 # If issues arise, ensure the service has the correct token or uncomment/correct credentials-file.
 tunnel: \$TUNNEL_ID
 \$CRED_FILE_LINE

 # Optional: Logdatei für cloudflared
 # logfile: /var/log/cloudflared.log
 # loglevel: info

 # Ingress rules define how traffic is routed from the tunnel
 # See: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress/
 ingress:
   # Regel 1: Leitet Anfragen für den angegebenen Hostnamen an den lokalen Service weiter
   - hostname: $HOSTNAME_TO_ROUTE
     service: $INTERNAL_SERVICE_URL
   # Regel 2: Fängt allen anderen Traffic ab und gibt 404 zurück (wichtig!)
   - service: http_status:404" | sudo tee "\$CLOUDFLARED_CONFIG_FILE" > /dev/null || R_error "Konnte Konfigurationsdatei \$CLOUDFLARED_CONFIG_FILE nicht schreiben."

    # Berechtigungen für config.yml setzen
    sudo chmod 644 "\$CLOUDFLARED_CONFIG_FILE" || R_error "Konnte Rechte für Config nicht setzen."

    R_success "Konfigurationsdatei \$CLOUDFLARED_CONFIG_FILE erstellt/aktualisiert."
    echo "--- Inhalt von \$CLOUDFLARED_CONFIG_FILE ---"
    sudo cat "\$CLOUDFLARED_CONFIG_FILE" || R_warning "Konnte Inhalt der Config nicht anzeigen."
    echo "------------------------------------"
    echo ""

    # --- 5. DNS-Route erstellen (als eingeloggter User, braucht cert.pem) ---
    R_info "Erstelle/Prüfe DNS CNAME-Eintrag für $HOSTNAME_TO_ROUTE bei Cloudflare..."
    cloudflared --origincert "\$USER_CERT_PATH" tunnel route dns "$TUNNEL_NAME" "$HOSTNAME_TO_ROUTE" || handle_non_critical_error "Konnte DNS-Route nicht automatisch erstellen/verifizieren (existiert evtl. schon?). Manuell prüfen!"
    echo ""

    # --- 6. Service installieren und starten (als root/sudo) ---
    R_info "Installiere/Aktualisiere und starte cloudflared als Systemd-Service mit sudo..."
    # Fehler beim Stoppen/Deaktivieren ignorieren (falls nicht vorhanden)
    sudo systemctl disable cloudflared >/dev/null 2>&1 || true
    sudo systemctl stop cloudflared >/dev/null 2>&1 || true
    # Installiere den Service (holt sich oft den Tunnel-Token selbst ODER nutzt die Credentials-Datei aus /etc/cloudflared)
    sudo cloudflared service install || R_error "Installation des cloudflared Service fehlgeschlagen."
    R_info "Service installiert. Aktiviere und starte..."
    sudo systemctl enable cloudflared || R_warning "Konnte cloudflared Service nicht aktivieren."
    sudo systemctl restart cloudflared || R_error "Konnte cloudflared Service nicht starten/neu starten."
    sleep 5 # Gib dem Service etwas mehr Zeit zum Starten
    R_info "Überprüfe Service-Status:"
    if sudo systemctl is-active --quiet cloudflared; then
        R_success "cloudflared Service läuft."
    else
        R_warning "cloudflared Service scheint nicht aktiv zu sein. Überprüfe Logs mit 'sudo journalctl -u cloudflared'."
        sudo systemctl status cloudflared --no-pager || true
    fi

    echo ""
    R_success "Cloudflare Tunnel Setup auf Pi abgeschlossen (mit potenziellen Warnungen)."
    R_info "Stelle sicher, dass dein lokaler Dienst unter '$INTERNAL_SERVICE_URL' auf dem Pi läuft."

    echo "*** Remote-Ausführung auf Pi beendet ***"

EOF

# Exit-Status des SSH-Befehls prüfen
SSH_EXIT_CODE=$?
if [ $SSH_EXIT_CODE -ne 0 ]; then
    # Unterscheide, ob der Fehler vom Remote-Skript kam (exit 1) oder die SSH-Verbindung selbst abbrach
    if [ $SSH_EXIT_CODE -eq 1 ]; then
         error "Ein Fehler ist im Remote-Skript auf dem Pi aufgetreten (siehe Meldungen oben)."
    else
         error "SSH-Befehl wurde unerwartet beendet (Exit Code: $SSH_EXIT_CODE)."
    fi
fi

echo ""
success "Gesamtes Skript abgeschlossen!"
info "Du kannst den Tunnel-Status auch im Cloudflare Zero Trust Dashboard überprüfen (Zero Trust -> Access -> Tunnels)."
info "Portweiterleitung und DynDNS werden für '$HOSTNAME_TO_ROUTE' nicht mehr benötigt."

exit 0