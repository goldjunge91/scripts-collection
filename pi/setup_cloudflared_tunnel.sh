#!/bin/bash

# Skript zur Einrichtung eines Cloudflare Tunnels (cloudflared) auf Raspberry Pi (Debian/Raspberry Pi OS)

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
read -r -p "Geben Sie den Benutzernamen für den SSH-Schlüssel ein [$(whoami)]: " SSH_USER
SSH_USER=${SSH_USER:-$(whoami)}
# Pfad zum SSH Private Key für die Verbindung zum Pi
SSH_KEY="/Users/$SSH_USER/.ssh/id_rsa_pi_colify"

# --- Banner ---
echo "============================================="
echo "   Raspberry Pi Coolify & Caddy Deployment   "
echo "============================================="
echo ""
info "Dieses Skript konfiguriert Docker, Coolify und Caddy auf einem entfernten Raspberry Pi via SSH."
echo ""


# IP-Adresse oder Hostname des Raspberry Pi abfragen
read -rp "Geben Sie die IP-Adresse oder den Hostnamen des Raspberry Pi ein: " PI_HOST
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
if ! ssh -i "$SSH_KEY" -p "$SSH_PORT" "$PI_USER"@"$PI_HOST" "echo SSH-Verbindung erfolgreich" >/dev/null 2>&1; then
    error "SSH-Verbindung fehlgeschlagen. Prüfe IP/Hostname, Benutzer, Port und SSH-Schlüssel ($SSH_KEY)."
fi
success "SSH-Verbindung erfolgreich."
echo ""

# --- Prüfen auf Root-Rechte ---
if [ "$(id -u)" -ne 0 ]; then
  error "Dieses Skript benötigt Root-Rechte. Bitte mit 'sudo $0' ausführen."
fi

# --- Variablen ---
CLOUDFLARED_CONFIG_DIR="/etc/cloudflared"
CLOUDFLARED_CONFIG_FILE="$CLOUDFLARED_CONFIG_DIR/config.yml"
# Tunnel-Name und Hostname werden abgefragt
TUNNEL_NAME=""
HOSTNAME_TO_ROUTE=""
# Interne Service-URL wird abgefragt - Standard: Lokaler Webserver auf Port 80
INTERNAL_SERVICE_URL="http://localhost:80"

# --- Banner ---
echo "============================================="
echo "  Cloudflare Tunnel (cloudflared) Setup      "
echo "============================================="
echo ""

# --- 1. cloudflared Installation ---
info "Installiere cloudflared..."

# Architektur prüfen (arm64 oder arm)
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "arm64" ]; then
  DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
elif [ "$ARCH" = "armhf" ] || [ "$ARCH" = "armel" ]; then
   # Unterscheidung armhf/armel nicht unbedingt nötig, arm sollte reichen
  DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.deb"
else
  error "Nicht unterstützte Architektur: $ARCH"
fi

TEMP_DEB="/tmp/cloudflared.deb"
info "Lade $DEB_URL herunter..."
if ! curl -L "$DEB_URL" -o "$TEMP_DEB"; then
  rm -f "$TEMP_DEB"
  error "Download von cloudflared fehlgeschlagen."
fi

info "Installiere Paket..."
if ! dpkg -i "$TEMP_DEB"; then
  warning "dpkg-Installation fehlgeschlagen. Versuche Abhängigkeiten aufzulösen..."
  apt --fix-broken install -y || { rm -f "$TEMP_DEB"; error "Konnte Abhängigkeiten nicht auflösen."; }
  # Erneuter Versuch nach Abhängigkeitsauflösung
  dpkg -i "$TEMP_DEB" || { rm -f "$TEMP_DEB"; error "Installation von cloudflared endgültig fehlgeschlagen."; }
fi
rm -f "$TEMP_DEB"
success "cloudflared erfolgreich installiert."
cloudflared --version
echo ""

# --- 2. Login bei Cloudflare ---
info "Starte Cloudflare Login-Prozess."
warning "Du musst dich nun in deinem Browser bei Cloudflare anmelden und die Domain autorisieren."
echo "Bitte kopiere die folgende URL, öffne sie in einem Browser auf einem beliebigen Gerät,"
echo "logge dich ein und wähle die Domain aus, die du verwenden möchtest (z.B. tozzi-test.de)."
echo ""
# Führt den Login-Prozess aus, der eine URL anzeigt
cloudflared login

echo ""
read -p ">>> Hast du dich erfolgreich im Browser angemeldet und die Domain ausgewählt? (j/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    error "Vorgang abgebrochen. Bitte melde dich bei Cloudflare an, um fortzufahren."
fi
success "Login-Schritt bestätigt."
echo ""

# --- 3. Tunnel erstellen ---
read -p "Gib einen Namen für deinen neuen Tunnel ein (z.B. 'pi-zuhause'): " TUNNEL_NAME
if [[ -z "$TUNNEL_NAME" ]]; then
    error "Kein Tunnel-Name angegeben."
fi

info "Erstelle Tunnel '$TUNNEL_NAME'..."
# Tunnel erstellen. Die Ausgabe enthält die Tunnel-ID und den Pfad zur Credentials-Datei.
# Beispiel-Ausgabe: Tunnel credentials written to /root/.cloudflared/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json. cloudflared chose this file based on where your origin certificate was found. Keep this file secret. To start the tunnel, run cloudflared tunnel run xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# Wir brauchen die ID für die config.yml
TUNNEL_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME" 2>&1) || error "Fehler beim Erstellen des Tunnels:\n$TUNNEL_OUTPUT"
echo "$TUNNEL_OUTPUT" # Zeige die Ausgabe an, damit der User die Infos sieht

# Versuche, die Tunnel ID zu extrahieren (kann fehlschlagen, wenn sich das Ausgabeformat ändert)
TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o '[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}')
CREDENTIALS_FILE_PATH="/root/.cloudflared/${TUNNEL_ID}.json" # Standardpfad für root-User

if [[ -z "$TUNNEL_ID" ]]; then
    warning "Konnte Tunnel-ID nicht automatisch extrahieren. Bitte manuell prüfen!"
    read -p "Bitte gib die Tunnel-ID ein (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx): " TUNNEL_ID
    [[ -z "$TUNNEL_ID" ]] && error "Keine Tunnel-ID angegeben."
    CREDENTIALS_FILE_PATH="/root/.cloudflared/${TUNNEL_ID}.json" # Annahme bleibt
else
    success "Tunnel '$TUNNEL_NAME' erstellt mit ID: $TUNNEL_ID"
fi
info "Die dazugehörige Credentials-Datei sollte hier liegen: $CREDENTIALS_FILE_PATH"
echo ""

# --- 4. Konfigurationsdatei erstellen ---
read -p "Welcher Hostname soll auf den Tunnel zeigen? (z.B. tozzi-test.de): " HOSTNAME_TO_ROUTE
[[ -z "$HOSTNAME_TO_ROUTE" ]] && error "Kein Hostname angegeben."

read -p "Welche lokale Service-URL soll dieser Hostname aufrufen? [${INTERNAL_SERVICE_URL}]: " USER_SERVICE_URL
INTERNAL_SERVICE_URL=${USER_SERVICE_URL:-$INTERNAL_SERVICE_URL}

info "Erstelle Konfigurationsdatei $CLOUDFLARED_CONFIG_FILE..."

# Stelle sicher, dass das Konfigurationsverzeichnis existiert
mkdir -p "$CLOUDFLARED_CONFIG_DIR"

# Schreibe die Konfiguration
# WICHTIG: Der Pfad zur Credentials-Datei muss für den User korrekt sein, unter dem der Service läuft!
# Wenn der Service als 'cloudflared' User läuft, muss die Datei ggf. nach /etc/cloudflared kopiert werden
# oder der Pfad hier angepasst werden. Wir gehen erstmal davon aus, dass der Service Zugriff hat.
# Sicherer Ansatz: Kopiere Credentials ins config dir und ändere Besitzer
CREDENTIALS_TARGET_PATH="$CLOUDFLARED_CONFIG_DIR/$TUNNEL_ID.json"
info "Kopiere Credentials nach $CREDENTIALS_TARGET_PATH"
cp "$CREDENTIALS_FILE_PATH" "$CREDENTIALS_TARGET_PATH" || error "Konnte Credentials-Datei nicht kopieren."
chown root:root "$CREDENTIALS_TARGET_PATH" # Oder cloudflared:cloudflared wenn der User existiert
chmod 600 "$CREDENTIALS_TARGET_PATH"

cat > "$CLOUDFLARED_CONFIG_FILE" << EOF
# Cloudflare Tunnel Configuration
# Tunnel ID and credentials file path
tunnel: $TUNNEL_ID
credentials-file: $CREDENTIALS_TARGET_PATH

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
  - service: http_status:404
EOF

# Berechtigungen für Config setzen
chown root:root "$CLOUDFLARED_CONFIG_FILE" # Oder cloudflared:cloudflared
chmod 644 "$CLOUDFLARED_CONFIG_FILE"

success "Konfigurationsdatei $CLOUDFLARED_CONFIG_FILE erstellt."
echo "--- Inhalt von $CLOUDFLARED_CONFIG_FILE ---"
cat "$CLOUDFLARED_CONFIG_FILE"
echo "------------------------------------"
echo ""


# --- 5. DNS-Route erstellen ---
info "Erstelle DNS CNAME-Eintrag für $HOSTNAME_TO_ROUTE bei Cloudflare..."
# Dieser Befehl erstellt automatisch einen CNAME-Eintrag in Cloudflare DNS,
# der $HOSTNAME_TO_ROUTE auf die spezielle Tunnel-URL (<tunnel-id>.cfargotunnel.com) zeigt.
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME_TO_ROUTE" || warning "Konnte DNS-Route nicht automatisch erstellen. Möglicherweise manuell in Cloudflare nötig (CNAME $HOSTNAME_TO_ROUTE -> $TUNNEL_ID.cfargotunnel.com)."
success "Versuch unternommen, DNS-Route zu erstellen."
echo ""


# --- 6. Service installieren und starten ---
info "Installiere und starte cloudflared als Systemd-Service..."

# Deaktiviere und stoppe evtl. alten Service, bevor neu installiert wird
systemctl disable cloudflared >/dev/null 2>&1
systemctl stop cloudflared >/dev/null 2>&1

# Installiere den Service (dies kopiert oft die config.yml und credentials)
cloudflared service install || error "Installation des cloudflared Service fehlgeschlagen."

# Aktiviere und starte den Service
systemctl enable cloudflared || warning "Konnte cloudflared Service nicht aktivieren."
systemctl start cloudflared || error "Konnte cloudflared Service nicht starten."

# Warte kurz und prüfe den Status
sleep 3
info "Überprüfe Service-Status:"
systemctl status cloudflared --no-pager

echo ""
success "Cloudflare Tunnel '$TUNNEL_NAME' sollte nun aktiv sein!"
info "Du kannst den Tunnel-Status auch im Cloudflare Zero Trust Dashboard überprüfen (Access -> Tunnels)."
info "Stelle sicher, dass dein lokaler Dienst unter '$INTERNAL_SERVICE_URL' auf dem Pi läuft."
info "Portweiterleitung und DynDNS werden für '$HOSTNAME_TO_ROUTE' nicht mehr benötigt."

exit 0