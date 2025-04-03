#!/bin/bash

# Einfaches Backup-Skript für Dateien und Verzeichnisse

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
  echo -e "${BLUE}[BACKUP]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Konfiguration
SOURCE_DIR="${1:-/path/to/source}"
BACKUP_DIR="${2:-/path/to/backup}"
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
RETENTION_DAYS=7

# Hilfe anzeigen, wenn --help oder -h angegeben wurde
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Verwendung: $0 [QUELLE] [ZIEL] [OPTIONEN]"
  echo ""
  echo "OPTIONEN:"
  echo "  --retention=DAYS  Anzahl der Tage, die Backups aufbewahrt werden sollen (Standard: 7)"
  echo ""
  echo "Beispiel:"
  echo "  $0 /home/user/data /mnt/backup --retention=30"
  exit 0
fi

# Parameter für Retention Days prüfen
for arg in "$@"; do
  if [[ $arg == "--retention="* ]]; then
    RETENTION_DAYS="${arg#*=}"
  fi
done

# Prüfen, ob Quellverzeichnis existiert
if [ ! -d "$SOURCE_DIR" ]; then
  print_error "Quellverzeichnis existiert nicht: $SOURCE_DIR"
  exit 1
fi

# Zielverzeichnis erstellen, falls es nicht existiert
if [ ! -d "$BACKUP_DIR" ]; then
  print_step "Zielverzeichnis wird erstellt: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
fi

# Backup erstellen
print_step "Backup wird erstellt: $SOURCE_DIR -> $BACKUP_DIR/$BACKUP_NAME"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# Prüfen, ob Backup erfolgreich war
if [ $? -eq 0 ]; then
  BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
  print_success "Backup erfolgreich erstellt: $BACKUP_DIR/$BACKUP_NAME ($BACKUP_SIZE)"
else
  print_error "Backup fehlgeschlagen!"
  exit 1
fi

# Alte Backups löschen
print_step "Alte Backups werden bereinigt (älter als $RETENTION_DAYS Tage)..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

print_success "Backup-Prozess abgeschlossen!"
