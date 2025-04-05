#!/bin/bash

# Raspberry Pi Coolify & Caddy Deployment Skript via SSH
# Richtet Docker, Coolify und Caddy (als Reverse Proxy) auf einem entfernten Raspberry Pi ein.
# Lädt Docker-Compose-Konfiguration aus externen Dateien.

# --- Konfiguration ---
# Pfad zum SSH Private Key für die Verbindung zum Pi
#SSH_KEY="/Users/marco/.ssh/id_rsa_pi_colify"
# Benutzername abfragen (Standard: aktueller Benutzer)
read -r -p "Geben Sie den Benutzernamen für den SSH-Schlüssel ein [$(whoami)]: " SSH_USER
SSH_USER=${SSH_USER:-$(whoami)}

# Pfad zum SSH Private Key für die Verbindung zum Pi
SSH_KEY="/Users/$SSH_USER/.ssh/id_rsa_pi_colify"
# Pfad zur Docker-Compose-Datei MIT Cloudflare-Integration (lokal)
COMPOSE_CLOUDFLARE_SRC="../docker/docker-compose.caddy.cloudflare.yml"
# Pfad zur Docker-Compose-Datei OHNE Cloudflare-Integration (lokal)
COMPOSE_NOCLOUDFLARE_SRC="../docker/docker-compose.caddy.nocloudflare.yml"

# --- Farben für Ausgaben ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Hilfsfunktionen ---
info() { echo -e "${BLUE}Info: $1${NC}"; }
success() { echo -e "${GREEN}Erfolg: $1${NC}"; }
warning() { echo -e "${YELLOW}Warnung: $1${NC}"; }
error() { echo -e "${RED}Fehler: $1${NC}" >&2; exit 1; }

# --- Banner ---
echo "============================================="
echo "   Raspberry Pi Coolify & Caddy Deployment   "
echo "============================================="
echo ""
info "Dieses Skript konfiguriert Docker, Coolify und Caddy auf einem entfernten Raspberry Pi via SSH."
echo ""
# Prüfen, ob das USB-Setup-Skript existiert
if [ ! -f "$COMPOSE_CLOUDFLARE_SRC" ]; then
    error "Das compose file für cloudflare wurde nicht gefunden: $COMPOSE_CLOUDFLARE_SRC"
fi
# Prüfen, ob das USB-Setup-Skript existiert
if [ ! -f "$COMPOSE_NOCLOUDFLARE_SRC" ]; then
    error "Das compose file für cloudflare wurde nicht gefunden: $COMPOSE_NOCLOUDFLARE_SRC"
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

# --- SSH-Verbindung testen ---
info "Teste SSH-Verbindung zu $PI_USER@$PI_HOST:$SSH_PORT..."
if ! ssh -i "$SSH_KEY" -p $SSH_PORT $PI_USER@$PI_HOST "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    error "SSH-Verbindung fehlgeschlagen. Prüfe IP/Hostname, Benutzer, Port und SSH-Schlüssel ($SSH_KEY)."
fi
success "SSH-Verbindung erfolgreich."
echo ""

# --- Domain- und E-Mail-Informationen abfragen ---
read -p "Bitte gib deine Domain ein (z.B. example.com): " USER_DOMAIN
[[ -z "$USER_DOMAIN" ]] && error "Keine Domain angegeben. Abbruch."
info "Domain $USER_DOMAIN wird für die Konfiguration verwendet."

read -p "Bitte gib eine Admin-E-Mail für SSL-Zertifikate ein: " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    warning "Keine Admin-E-Mail angegeben. Verwende admin@$USER_DOMAIN als Standard."
    ADMIN_EMAIL="admin@$USER_DOMAIN"
fi
echo ""

# --- Cloudflare-Einrichtung abfragen ---
CLOUDFLARE_TOKEN=""
CLOUDFLARE_EMAIL=""
USE_CLOUDFLARE=false
read -p "Möchtest du Cloudflare für automatische SSL-Zertifikate einrichten? (j/n): " setup_cloudflare
if [[ "$setup_cloudflare" == "j" || "$setup_cloudflare" == "J" ]]; then
    read -p "Gib deinen Cloudflare API-Token ein: " CLOUDFLARE_TOKEN
    # E-Mail ist für den Caddy DNS Provider nicht unbedingt nötig, aber gut für die env-Datei
    read -p "Gib deine Cloudflare E-Mail-Adresse ein (optional, für Referenz): " CLOUDFLARE_EMAIL
    [[ -z "$CLOUDFLARE_TOKEN" ]] && error "Cloudflare API-Token wurde nicht angegeben."
    USE_CLOUDFLARE=true
    info "Cloudflare wird für SSL-Zertifikate verwendet."

    # Hinweis zur DNS-Konfiguration
    info "Wichtig: Richte in deinem Cloudflare-Dashboard folgende DNS-Einträge ein:"
    info "  - A-Record: $USER_DOMAIN → Deine öffentliche IP des Raspberry Pi"
    info "  - A-Record: *.${USER_DOMAIN} → Deine öffentliche IP des Raspberry Pi (für Subdomains)"
    info "  - Aktiviere den Proxy-Status (orangene Wolke) für bessere Sicherheit (optional, Caddy muss dann ggf. anders konfiguriert werden)"
    info "  - Stelle sicher, dass SSL auf 'Voll (Strict)' eingestellt ist (empfohlen)"

else
    info "Cloudflare wird nicht für SSL-Zertifikate verwendet. Caddy wird Let's Encrypt direkt nutzen (HTTP- oder TLS-ALPN-Challenge)."
    info "Stelle sicher, dass Port 80 und 443 auf dem Router zum Pi weitergeleitet werden und über die Domain erreichbar sind."
fi
echo ""

# --- Temporäre Dateien für Konfiguration vorbereiten ---
info "Bereite Konfigurationsdateien lokal vor..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT # Stellt sicher, dass das Temp-Verzeichnis bei Skriptende gelöscht wird

# Caddyfile lokal erstellen
CADDYFILE_LOCAL="$TMP_DIR/Caddyfile"
cat > "$CADDYFILE_LOCAL" << EOF
{
    # Globale Optionen
    email ${ADMIN_EMAIL}
$( [[ "$USE_CLOUDFLARE" == true ]] && echo "    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}" )
}

${USER_DOMAIN} {
    reverse_proxy localhost:3000 # Port deiner Coolify-Instanz (Standard)
$( [[ "$USE_CLOUDFLARE" == true ]] && echo -e "    tls {\n        dns cloudflare {env.CLOUDFLARE_API_TOKEN}\n    }" )
}

# Beispiel für eine weitere Subdomain (z.B. für eine API)
# api.${USER_DOMAIN} {
#     reverse_proxy localhost:8000 # Port deiner API
# $( [[ "$USE_CLOUDFLARE" == true ]] && echo -e "    tls {\n        dns cloudflare {env.CLOUDFLARE_API_TOKEN}\n    }" )
# }

# Füge hier bei Bedarf weitere Subdomains hinzu...
EOF
success "Caddyfile lokal erstellt: $CADDYFILE_LOCAL"

# Cloudflare env-Datei lokal erstellen (wenn nötig)
CLOUDFLARE_ENV_LOCAL=""
if [[ "$USE_CLOUDFLARE" == true ]]; then
    CLOUDFLARE_ENV_LOCAL="$TMP_DIR/cloudflare.env"
    cat > "$CLOUDFLARE_ENV_LOCAL" << EOF
# Cloudflare Credentials for Caddy Docker Container
CLOUDFLARE_API_TOKEN=${CLOUDFLARE_TOKEN}
# CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL} # Nur zur Referenz, wird von Caddy nicht direkt benötigt
EOF
    success "Cloudflare env-Datei lokal erstellt: $CLOUDFLARE_ENV_LOCAL"
fi

# Passende Docker-Compose-Datei auswählen
if [[ "$USE_CLOUDFLARE" == true ]]; then
    COMPOSE_SRC=$COMPOSE_CLOUDFLARE_SRC
else
    COMPOSE_SRC=$COMPOSE_NOCLOUDFLARE_SRC
fi

if [ ! -f "$COMPOSE_SRC" ]; then
    error "Benötigte Docker-Compose-Quelldatei nicht gefunden: $COMPOSE_SRC"
fi
success "Verwende Docker-Compose-Datei: $COMPOSE_SRC"
echo ""


# --- Konfiguration auf Raspberry Pi übertragen ---
info "Übertrage Konfigurationsdateien auf den Raspberry Pi..."
PI_BASE_DIR="\$HOME" # Remote Home Directory
PI_CADDY_DIR="$PI_BASE_DIR/caddy"
PI_CADDY_ENV_DIR="$PI_CADDY_DIR/env"

# Verzeichnisse auf Pi erstellen (ignoriere Fehler, falls schon vorhanden)
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$PI_USER@$PI_HOST" "mkdir -p '$PI_CADDY_DIR' '$PI_CADDY_DIR/data' '$PI_CADDY_DIR/config'" || warning "Konnte Caddy-Verzeichnisse auf Pi nicht erstellen (existieren vielleicht schon)."

# Docker-Compose übertragen
info "Übertrage docker-compose.yml..."
scp -i "$SSH_KEY" -P "$SSH_PORT" "$COMPOSE_SRC" "$PI_USER@$PI_HOST:$PI_CADDY_DIR/docker-compose.yml" || error "Übertragung der docker-compose.yml fehlgeschlagen."

# Caddyfile übertragen
info "Übertrage Caddyfile..."
scp -i "$SSH_KEY" -P "$SSH_PORT" "$CADDYFILE_LOCAL" "$PI_USER@$PI_HOST:$PI_CADDY_DIR/Caddyfile" || error "Übertragung der Caddyfile fehlgeschlagen."

# Cloudflare env-Datei übertragen (wenn nötig)
if [[ "$USE_CLOUDFLARE" == true ]]; then
    info "Übertrage cloudflare.env..."
    ssh -i "$SSH_KEY" -p "$SSH_PORT" "$PI_USER@$PI_HOST" "mkdir -p '$PI_CADDY_ENV_DIR'" || warning "Konnte env-Verzeichnis auf Pi nicht erstellen."
    scp -i "$SSH_KEY" -P "$SSH_PORT" "$CLOUDFLARE_ENV_LOCAL" "$PI_USER@$PI_HOST:$PI_CADDY_ENV_DIR/cloudflare.env" || error "Übertragung der cloudflare.env fehlgeschlagen."
fi
success "Konfigurationsdateien erfolgreich übertragen."
echo ""


# --- Software Installation und Setup auf Raspberry Pi ausführen ---
info "Führe Installation und Setup auf dem Raspberry Pi aus (dies kann einige Minuten dauern)..."
ssh -i "$SSH_KEY" -p "$SSH_PORT" -t "$PI_USER@$PI_HOST" << EOF || error "Fehler bei der Remote-Ausführung auf dem Pi."
set -e # Beende sofort bei Fehlern

echo "*** (Remote-Ausführung auf $PI_HOST als $PI_USER) ***"

# 1. Docker Installation
echo ">>> Installiere/Update Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $PI_USER
    echo ">>> Docker installiert. WICHTIG: Docker-Gruppenänderung wird erst nach Neuanmeldung des Benutzers '$PI_USER' auf dem Pi wirksam!"
    rm get-docker.sh
else
    echo ">>> Docker scheint bereits installiert zu sein."
    # Sicherstellen, dass der Benutzer in der Docker-Gruppe ist
    if ! groups $PI_USER | grep -q '\bdocker\b'; then
        sudo usermod -aG docker $PI_USER
        echo ">>> Benutzer '$PI_USER' zur Docker-Gruppe hinzugefügt. Neuanmeldung auf Pi erforderlich."
    fi
fi

# 2. Docker Compose Plugin prüfen (wird meist mit Docker installiert)
echo ">>> Prüfe Docker Compose Plugin..."
if ! docker compose version &> /dev/null; then
    echo ">>> Docker Compose Plugin nicht gefunden. Versuche Installation..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin || echo "WARNUNG: Konnte Docker Compose Plugin nicht automatisch installieren."
else
    echo ">>> Docker Compose Plugin gefunden."
fi


# 3. Coolify Installation
echo ">>> Installiere/Update Coolify..."
COOLIFY_DIR="/data/coolify"
if [ ! -d "\$COOLIFY_DIR" ]; then
    sudo mkdir -p \$COOLIFY_DIR
    cd \$COOLIFY_DIR
    wget -q https://get.coolify.io/coolify.sh
    sudo bash coolify.sh
    echo ">>> Coolify wurde installiert."
else
    echo ">>> Coolify-Verzeichnis (\$COOLIFY_DIR) existiert bereits. Überspringe Installation."
    # Hier könnte man optional ein Update-Skript von Coolify aufrufen, falls verfügbar
fi

# 4. Docker Netzwerk erstellen (falls nicht vorhanden)
echo ">>> Stelle Docker-Netzwerk 'caddy_net' sicher..."
docker network inspect caddy_net >/dev/null 2>&1 || docker network create caddy_net

# 5. Caddy starten
echo ">>> Starte Caddy via Docker Compose..."
cd "$PI_CADDY_DIR"
docker compose down # Stoppe evtl. alte Container, bevor neu gestartet wird
docker compose up -d --remove-orphans

echo "*** (Remote-Ausführung auf Pi beendet) ***"
EOF

success "Remote-Installation und Setup abgeschlossen."
echo ""

# --- Abschließende Informationen ---
info "Zusammenfassung der Konfiguration:"
info "- Domain: $USER_DOMAIN"
info "- Admin-E-Mail: $ADMIN_EMAIL"
if [[ "$USE_CLOUDFLARE" == true ]]; then
    info "- SSL-Zertifikate: Via Cloudflare DNS Challenge"
    info "Vorteile der Cloudflare-Integration (kostenlose Version):"
    info "  - Kostenloser CDN, DDoS-Schutz, DNS-Management, SSL, Caching, Analytics, IP-Maskierung."
else
    info "- SSL-Zertifikate: Via Let's Encrypt (direkt über HTTP/TLS-ALPN Challenge)"
fi
echo ""
warning "WICHTIG: Falls der Benutzer '$PI_USER' gerade erst zur Docker-Gruppe hinzugefügt wurde, muss er sich auf dem Raspberry Pi aus- und wieder einloggen, damit er Docker-Befehle ohne 'sudo' ausführen kann (relevant für Coolify)."
echo ""
success "Setup abgeschlossen! Dein Raspberry Pi sollte nun mit Docker, Coolify und Caddy für $USER_DOMAIN konfiguriert sein."
info "Du kannst den Status der Caddy-Container auf dem Pi prüfen mit: ssh -i \"$SSH_KEY\" -p \"$SSH_PORT\" \"$PI_USER@$PI_HOST\" 'cd $PI_CADDY_DIR && docker compose ps'"

# Lokale temporäre Dateien werden durch 'trap' am Anfang automatisch gelöscht.

exit 0