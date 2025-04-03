#!/bin/bash

# MongoDB Installation für Ubuntu 22.04

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Abhängigkeiten installieren
print_step "Abhängigkeiten werden installiert..."
sudo apt update
sudo apt install -y gnupg curl

# MongoDB Repository hinzufügen
print_step "MongoDB Repository wird hinzugefügt..."
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
   --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# MongoDB installieren
print_step "MongoDB wird installiert..."
sudo apt update
sudo apt install -y mongodb-org

# MongoDB aktivieren und starten
print_step "MongoDB wird gestartet..."
sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod

# Firewall-Regeln (optional)
print_step "Firewall wird konfiguriert (nur für localhost)..."
sudo ufw allow from 127.0.0.1 to any port 27017

# Status prüfen
if systemctl is-active --quiet mongod; then
  print_success "MongoDB wurde erfolgreich installiert und läuft!"
  echo "MongoDB Version: $(mongod --version | grep 'db version' | sed 's/db version v//')"
else
  echo -e "${RED}[ERROR]${NC} MongoDB konnte nicht gestartet werden. Bitte prüfen Sie die Logs mit: sudo journalctl -u mongod"
fi
