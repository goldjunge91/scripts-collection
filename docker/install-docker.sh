#!/bin/bash

# Docker und Docker Compose Installation für Ubuntu

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Alte Versionen entfernen
print_step "Alte Docker-Versionen werden entfernt..."
sudo apt remove -y docker docker-engine docker.io containerd runc || true

# Abhängigkeiten installieren
print_step "Abhängigkeiten werden installiert..."
sudo apt update
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Docker's GPG-Schlüssel hinzufügen
print_step "Docker GPG-Schlüssel wird hinzugefügt..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Docker Repository einrichten
print_step "Docker Repository wird eingerichtet..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
print_step "Docker wird installiert..."
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Docker als Service starten
print_step "Docker wird gestartet..."
sudo systemctl enable docker
sudo systemctl start docker

# Aktuellen Benutzer zur Docker-Gruppe hinzufügen
print_step "Benutzer zur Docker-Gruppe hinzufügen..."
sudo usermod -aG docker $USER
print_step "Beachten Sie: Sie müssen sich ab- und wieder anmelden, damit die Gruppenänderung wirksam wird."

# Docker Compose installieren
print_step "Docker Compose wird installiert..."
sudo apt update
sudo apt install -y docker-compose-plugin

# Versionen prüfen
print_step "Installation wird überprüft..."
if [ -x "$(command -v docker)" ]; then
  DOCKER_VERSION=$(docker --version)
  print_success "Docker wurde erfolgreich installiert: $DOCKER_VERSION"
else
  print_error "Docker Installation fehlgeschlagen!"
fi

if [ -x "$(command -v docker-compose)" ]; then
  COMPOSE_VERSION=$(docker-compose --version)
  print_success "Docker Compose wurde erfolgreich installiert: $COMPOSE_VERSION"
else
  print_error "Docker Compose Installation fehlgeschlagen oder Docker Compose ist noch nicht in Ihrem PATH."
  print_step "Sie können Docker Compose möglicherweise mit 'docker compose' aufrufen."
fi

print_success "Docker-Installation abgeschlossen!"
print_step "Bitte starten Sie Ihr Terminal neu oder führen Sie 'newgrp docker' aus, um Docker ohne sudo zu verwenden."
