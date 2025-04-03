#!/bin/bash

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Anzeigen von Fortschritt
print_step() {
  echo -e "${BLUE}[SETUP]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Schritt 1: System-Update und Installation von ZSH
print_step "System wird aktualisiert und ZSH installiert..."
sudo apt update && sudo apt install zsh curl git -y

# Schritt 2: Installation von NVM
print_step "NVM wird installiert..."
export NVM_DIR="$HOME/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# NVM in der aktuellen Session verfügbar machen
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ZSH-Konfiguration aktualisieren für NVM
print_step "ZSH-Konfiguration wird aktualisiert..."
if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

# Prüfen, ob NVM-Konfiguration bereits in .zshrc vorhanden ist
if ! grep -q "NVM_DIR" "$HOME/.zshrc"; then
  cat >> "$HOME/.zshrc" << 'EOF'

# NVM-Konfiguration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
fi

# Schritt 3: Installation von Node.js LTS
print_step "Node.js LTS wird installiert..."
nvm install --lts
nvm use --lts

# Schritt 4: Corepack aktivieren
print_step "Corepack wird aktiviert..."
corepack enable

# Schritt 5: PNPM 9.1.0 installieren
print_step "PNPM 9.1.0 wird installiert..."
corepack prepare pnpm@9.1.0 --activate

# Installation überprüfen
print_step "Überprüfung der Installation..."
NODE_VERSION=$(node -v)
NVM_VERSION=$(nvm -v)
PNPM_VERSION=$(pnpm -v)
ZSH_VERSION=$(zsh --version)

print_success "Installation abgeschlossen!"
echo "ZSH: $ZSH_VERSION"
echo "NVM: $NVM_VERSION"
echo "Node.js: $NODE_VERSION"
echo "PNPM: $PNPM_VERSION"

print_step "Um die Änderungen zu übernehmen, führen Sie bitte aus:"
echo "source ~/.zshrc"
print_step "Um ZSH als Standard-Shell zu setzen:"
echo "chsh -s $(which zsh)"
