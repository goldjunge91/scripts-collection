#!/bin/bash

# Grundlegende Konfiguration für einen Ubuntu-Server

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

# System aktualisieren
print_step "System wird aktualisiert..."
sudo apt update && sudo apt upgrade -y

# Grundlegende Tools installieren
print_step "Grundlegende Tools werden installiert..."
sudo apt install -y \
  build-essential \
  curl \
  wget \
  git \
  htop \
  vim \
  unzip \
  net-tools \
  ufw \
  fail2ban

# Firewall konfigurieren
print_step "Firewall wird konfiguriert..."
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Fail2ban konfigurieren
print_step "Fail2ban wird konfiguriert..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Swap-Datei erstellen (wenn keine vorhanden ist)
if [ ! -f /swapfile ]; then
  print_step "Swap-Datei wird erstellt..."
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Sicherheitseinstellungen
print_step "Sicherheitseinstellungen werden angepasst..."
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

print_success "Grundlegende Server-Einrichtung abgeschlossen!"
