# error_handler.sh - Dokumentation

## Übersicht
Das `error_handler.sh`-Skript bietet ein robustes Fehlerbehandlungs- und Logging-System für Bash-Skripte.

## Konfiguration
- `ERROR_LOG_FILE`: Pfad zur Log-Datei (überschreibbar)
- `DEBUG`: Debug-Modus aktivieren/deaktivieren (überschreibbar)

## Hauptfunktionen

### Log-Funktionen
- `log_info`: Informationsmeldungen
- `log_warn`: Warnungen
- `log_error`: Fehlermeldungen
- `log_fatal`: Kritische Fehler (beendet Skript)
- `log_debug`: Debug-Meldungen (nur wenn DEBUG=1)
- `_write_log`: Interne Funktion zum Schreiben in Log-Datei

### Fehlerbehandlung
- `_handle_error`: Automatische Fehlerbehandlung via ERR-Trap
  - Sammelt Kontext (Exit-Code, Zeilennummer, Befehl, Call-Stack)
  - Loggt Fehlerdetails
  - Beendet Skript mit originalem Fehlercode

### Setup
`setup_error_handling`: Initialisiert das System
- Aktiviert "strict mode" (set -Eeuo pipefail)
- Konfiguriert ERR-Trap
- Setzt Standard-Logpfad
- Exportiert Funktionen

## Integration in eigene Skripte

1. Kopiere `error_handler.sh` in dein Projektverzeichnis
2. Füge am Anfang deines Skripts ein: