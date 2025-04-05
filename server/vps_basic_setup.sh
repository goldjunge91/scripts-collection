#!/bin/bash
#sudo ps aux | grep nginx
#sudo chmod -R 755 /etc/letsencrypt/live/
#sudo chmod -R 755 /etc/letsencrypt/archive/
#sudo find /etc/letsencrypt/archive/ -name "privkey*.pem" -exec chmod 640 {} \;
#sudo find /etc/letsencrypt/live/ -name "privkey*.pem" -exec chmod 640 {} \;
#sudo chown -R root:www-data /etc/letsencrypt/live/
#sudo chown -R root:www-data /etc/letsencrypt/archive/
# Erweitertes SSL-Zertifikat-Setup mit Certbot für Nginx
# Unterstützt mehrere Domains, Subdomains und optimierte Reverse-Proxy-Konfiguration

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging-Funktionen
print_step() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNUNG]${NC} $1"
}

# Root-Rechte-Überprüfung
if [ "$(id -u)" -ne 0 ]; then
  print_error "Dieses Skript muss mit Root-Rechten ausgeführt werden."
  print_error "Bitte verwenden Sie: sudo $0"
  exit 1
fi

# Prüfen, ob Nginx installiert ist
if ! command -v nginx &> /dev/null; then
  print_error "Nginx ist nicht installiert. Bitte installieren Sie Nginx zuerst:"
  print_error "sudo apt update && sudo apt install -y nginx"
  exit 1
fi

# Installiere notwendige Tools
print_step "Installiere notwendige Tools..."
apt update
apt install -y dnsutils curl

# Hauptdomain abfragen
read -p "Hauptdomain für das SSL-Zertifikat (z.B. jetwash-mobile.de): " MAIN_DOMAIN

if [ -z "$MAIN_DOMAIN" ]; then
  print_error "Es wurde keine Domain angegeben. Beende."
  exit 1
fi

# Fragen, ob www-Subdomain auch eingerichtet werden soll
read -p "Möchten Sie auch die www-Subdomain einrichten? (j/n): " INCLUDE_WWW
DOMAIN_ARGS="-d $MAIN_DOMAIN"

if [[ "$INCLUDE_WWW" =~ ^[jJyY]$ ]]; then
  DOMAIN_ARGS="$DOMAIN_ARGS -d www.$MAIN_DOMAIN"
  print_step "Die www-Subdomain wird ebenfalls eingerichtet."
fi

# Abfrage für zusätzliche Subdomains
read -p "Möchten Sie zusätzliche Subdomains einrichten? (z.B. app.$MAIN_DOMAIN) (j/n): " ADD_SUBDOMAINS

if [[ "$ADD_SUBDOMAINS" =~ ^[jJyY]$ ]]; then
  read -p "Geben Sie die Subdomains durch Komma getrennt ein (z.B. app,api,admin): " SUBDOMAINS

  if [ ! -z "$SUBDOMAINS" ]; then
    IFS=',' read -ra SUBDOMAIN_ARRAY <<< "$SUBDOMAINS"
    for subdomain in "${SUBDOMAIN_ARRAY[@]}"; do
      subdomain=$(echo "$subdomain" | tr -d ' ')
      if [ ! -z "$subdomain" ]; then
        DOMAIN_ARGS="$DOMAIN_ARGS -d $subdomain.$MAIN_DOMAIN"
        print_step "Subdomain $subdomain.$MAIN_DOMAIN wird eingerichtet."
      fi
    done
  fi
fi

# Fragen, ob Testumgebung verwendet werden soll
read -p "Möchten Sie die Let's Encrypt-Testumgebung verwenden? (empfohlen für Tests) (j/n): " USE_STAGING
STAGING_ARG=""

if [[ "$USE_STAGING" =~ ^[jJyY]$ ]]; then
  STAGING_ARG="--staging"
  print_warning "Testumgebung wird verwendet. Das Zertifikat wird nicht vertrauenswürdig sein."
fi

# Abfragen des lokalen Ports für den Proxy
read -p "Auf welchem lokalen Port läuft Ihre Anwendung? (z.B. 3000): " APP_PORT
if [ -z "$APP_PORT" ]; then
  APP_PORT="3000"
  print_step "Standard-Port 3000 wird verwendet."
fi

# Abfragen, ob Stripe-Webhook-Konfiguration gewünscht ist
read -p "Benötigen Sie eine spezielle Konfiguration für Stripe-Webhooks? (j/n): " STRIPE_WEBHOOKS
STRIPE_CONFIG=""

if [[ "$STRIPE_WEBHOOKS" =~ ^[jJyY]$ ]]; then
  read -p "Pfad für Stripe-Webhooks (z.B. /api/stripe/webhooks): " STRIPE_PATH
  if [ -z "$STRIPE_PATH" ]; then
    STRIPE_PATH="/api/stripe/webhooks"
  fi

  STRIPE_CONFIG="
    location $STRIPE_PATH {
        # Important: Don't buffer the request body
        proxy_buffering off;
        proxy_request_buffering off;

        # Set appropriate size limits
        client_max_body_size 10M;

        # Pass the request to your Node.js application
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;

        # Pass headers without modification
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Don't modify the request body
        proxy_set_header Content-Type \$http_content_type;
        proxy_set_header Content-Length \$http_content_length;

        # Pass the stripe-signature header without modification
        proxy_set_header stripe-signature \$http_stripe_signature;
    }"

  print_step "Stripe-Webhook-Konfiguration für $STRIPE_PATH hinzugefügt."
fi

# Prüfen, ob die Domains korrekt auf diesen Server zeigen
print_step "Prüfe, ob die Domains auf diesen Server zeigen..."
SERVER_IP=$(hostname -I | cut -d' ' -f1)

# Extrahiere alle Domains aus den DOMAIN_ARGS
ALL_DOMAINS=$(echo "$DOMAIN_ARGS" | sed 's/-d //g')
HAS_DNS_ISSUES=false

for domain in $ALL_DOMAINS; do
  print_step "Prüfe DNS für $domain..."
  DOMAIN_IP=$(dig +short $domain)

  if [ -z "$DOMAIN_IP" ]; then
    print_warning "Die Domain $domain scheint nicht konfiguriert zu sein oder der DNS-Eintrag ist noch nicht aktiv."
    HAS_DNS_ISSUES=true
  elif [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    print_warning "Die Domain $domain zeigt auf $DOMAIN_IP, aber Ihr Server hat die IP $SERVER_IP."
    HAS_DNS_ISSUES=true
  else
    print_success "Die Domain $domain zeigt korrekt auf diesen Server ($SERVER_IP)."
  fi
done

if [ "$HAS_DNS_ISSUES" = true ]; then
  read -p "Es wurden DNS-Probleme festgestellt. Möchten Sie trotzdem fortfahren? (j/n): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[jJyY]$ ]]; then
    print_step "Beende auf Anforderung des Benutzers."
    exit 0
  fi
fi

# Snap und Certbot installieren
print_step "Prüfe, ob Snap installiert ist..."
if ! command -v snap &> /dev/null; then
  print_step "Snap wird installiert..."
  apt update
  apt install -y snapd
  snap install core
  snap refresh core
fi

# Certbot installieren
print_step "Certbot wird installiert..."
snap install --classic certbot

# Certbot im PATH verfügbar machen
if [ ! -f /usr/bin/certbot ]; then
  print_step "Certbot-Symlink wird erstellt..."
  ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# Nginx-Plugin für Certbot installieren
print_step "Certbot Nginx-Plugin wird installiert..."
apt update
apt install -y python3-certbot-nginx

# Prüfen, ob Port 80 und 443 offen sind
print_step "Prüfe, ob die benötigten Ports offen sind..."
if ! command -v netstat &> /dev/null; then
  print_step "Das Paket net-tools wird installiert..."
  apt update
  apt install -y net-tools
fi

if ! netstat -tuln | grep -q ":80 "; then
  print_warning "Port 80 scheint nicht geöffnet zu sein. Let's Encrypt benötigt diesen Port für die Validierung."
  read -p "Möchten Sie fortfahren? (j/n): " CONTINUE_PORT
  if [[ ! "$CONTINUE_PORT" =~ ^[jJyY]$ ]]; then
    print_step "Beende auf Anforderung des Benutzers."
    exit 0
  fi
fi

# Nginx-Konfiguration für jede Domain vorbereiten
print_step "Erstelle Nginx-Konfiguration für die Domain(s)..."

for domain in $ALL_DOMAINS; do
  # Nur die Hauptdomain und ihre Subdomains, nicht die www-Version
  if [[ "$domain" != www.* ]]; then
    CONFIG_PATH="/etc/nginx/sites-available/$domain"

    # Erstelle Verzeichnisstruktur falls nötig
    mkdir -p /var/www/$domain/html

    # Erstelle eine einfache Index-Datei
    cat > /var/www/$domain/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Willkommen auf $domain</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #0066cc;
        }
    </style>
</head>
<body>
    <h1>Willkommen auf $domain!</h1>
    <p>Diese Seite wurde automatisch durch das SSL-Setup-Skript erstellt.</p>
    <p>Die SSL-Zertifikate wurden erfolgreich installiert.</p>
</body>
</html>
EOF

    # Erstelle die Nginx-Konfiguration für HTTP (wird von Certbot später aktualisiert)
    cat > $CONFIG_PATH << EOF
server {
    listen 80;
    listen [::]:80;

    root /var/www/$domain/html;
    index index.html index.htm index.nginx-debian.html;

    server_name $domain;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Zusätzliche Sicherheitseinstellungen
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

    # Aktiviere die Konfiguration
    ln -sf $CONFIG_PATH /etc/nginx/sites-enabled/

    # Setze die Berechtigungen
    chown -R www-data:www-data /var/www/$domain

    print_success "Basiskonfiguration für $domain erstellt."
  fi
done

# Entferne default, falls vorhanden und nicht benötigt
if [ -f /etc/nginx/sites-enabled/default ]; then
  print_step "Deaktiviere die Standard-Site..."
  rm -f /etc/nginx/sites-enabled/default
fi

# Konfiguration testen und Nginx neu starten
print_step "Teste Nginx-Konfiguration..."
nginx -t

if [ $? -ne 0 ]; then
  print_error "Fehler in der Nginx-Konfiguration. Bitte beheben Sie die Fehler und versuchen Sie es erneut."
  exit 1
fi

print_step "Starte Nginx neu..."
systemctl restart nginx

# Zertifikat erstellen und Nginx konfigurieren
print_step "SSL-Zertifikat wird angefordert und Nginx konfiguriert..."
certbot --nginx $STAGING_ARG $DOMAIN_ARGS --redirect --agree-tos --email admin@$MAIN_DOMAIN

# Prüfen, ob die Installation erfolgreich war
if [ $? -eq 0 ]; then
  print_success "SSL-Zertifikat für die Domain(s) wurde erfolgreich eingerichtet!"

  # Für jede Domain die Reverse-Proxy-Konfiguration erstellen
  for domain in $ALL_DOMAINS; do
    # Nur die Hauptdomain und ihre Subdomains, nicht die www-Version
    if [[ "$domain" != www.* ]]; then
      # Pfad zur Konfigurationsdatei
      CONFIG_PATH="/etc/nginx/sites-available/$domain"

      # Backup der Certbot-Konfiguration
      cp $CONFIG_PATH ${CONFIG_PATH}.certbot.backup

      # Extrahiere Zertifikatspfade aus der Certbot-Konfiguration
      SSL_CERT=$(grep "ssl_certificate " $CONFIG_PATH | head -1 | awk '{print $2}' | sed 's/;//')
      SSL_KEY=$(grep "ssl_certificate_key " $CONFIG_PATH | head -1 | awk '{print $2}' | sed 's/;//')

      if [ -z "$SSL_CERT" ] || [ -z "$SSL_KEY" ]; then
        print_warning "Konnte SSL-Zertifikatspfade für $domain nicht ermitteln. Die Proxy-Konfiguration wird nicht erstellt."
        continue
      fi

      # Erstelle die Reverse-Proxy-Konfiguration
      cat > $CONFIG_PATH << EOF
# HTTP-Server für Weiterleitung zu HTTPS
server {
    server_name $domain;
    listen 80;
    listen [::]:80;

    # Weiterleitung zu HTTPS
    return 301 https://\$host\$request_uri;
}

# HTTPS-Server mit Proxy zum lokalen Port
server {
    listen [::]:443 ssl; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    server_name $domain;

    # SSL-Zertifikate
    ssl_certificate $SSL_CERT; # managed by Certbot
    ssl_certificate_key $SSL_KEY; # managed by Certbot

    # SSL-Konfiguration
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    # Hauptproxy für die Anwendung
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
    $STRIPE_CONFIG
}
EOF

      print_success "Reverse-Proxy-Konfiguration für $domain erstellt."
    fi
  done

  # Konfiguration testen und Nginx neu starten
  print_step "Teste die aktualisierte Nginx-Konfiguration..."
  nginx -t

  if [ $? -eq 0 ]; then
    print_step "Starte Nginx neu..."
    systemctl restart nginx

    print_success "Reverse-Proxy-Konfiguration erfolgreich eingerichtet!"
    print_step "Ihre Website ist jetzt über HTTPS verfügbar: https://$MAIN_DOMAIN"

    # Timer für automatische Erneuerung anzeigen
    print_step "Die automatische Erneuerung wurde eingerichtet. Certbot wird das Zertifikat erneuern, bevor es abläuft."
    print_step "Sie können die automatische Erneuerung manuell testen mit:"
    echo "sudo certbot renew --dry-run"

    # Zusätzliche Informationen anzeigen
    if [[ "$USE_STAGING" =~ ^[jJyY]$ ]]; then
      print_warning "Sie haben ein Test-Zertifikat installiert. Für ein vertrauenswürdiges Zertifikat führen Sie das Skript erneut ohne Testumgebung aus."
    fi
  else
    print_error "Fehler in der Nginx-Konfiguration. Manuelle Anpassung erforderlich."
    print_step "Sie können auf die Backup-Konfiguration zurückgreifen:"
    for domain in $ALL_DOMAINS; do
      if [[ "$domain" != www.* ]]; then
        echo "cp /etc/nginx/sites-available/${domain}.certbot.backup /etc/nginx/sites-available/$domain"
      fi
    done
  fi
else
  print_error "Bei der Einrichtung des SSL-Zertifikats ist ein Fehler aufgetreten."
  print_step "Bitte überprüfen Sie die Fehlermeldungen oben und stellen Sie sicher, dass:"
  echo "- Die Domain korrekt konfiguriert ist"
  echo "- Port 80 und 443 in Ihrer Firewall geöffnet sind"
  echo "- Die Nginx-Konfiguration korrekt ist"

  if [[ ! "$USE_STAGING" =~ ^[jJyY]$ ]]; then
    print_step "Sie können es mit der Let's Encrypt-Testumgebung versuchen, um Rate-Limits zu vermeiden:"
    echo "sudo $0 -- mit 'j' bei der Frage nach der Testumgebung"
  fi
fi

# Hinweise zur SSL-Konfiguration anzeigen
print_step "Tipps zur Verbesserung der SSL-Konfiguration:"
echo "1. Sie können Ihre SSL-Konfiguration testen unter: https://www.ssllabs.com/ssltest/analyze.html?d=$MAIN_DOMAIN"
echo "2. Für eine optimierte SSL-Konfiguration können Sie Mozilla's SSL Configuration Generator verwenden:"
echo "   https://ssl-config.mozilla.org/"