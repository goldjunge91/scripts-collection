#!/bin/bash
# Dateiname: user_input.sh
# Wiederverwendbare Funktionen für verbesserte Benutzereingaben

# --- Farbdefinitionen ---
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

# Wiederverwendbare Funktion für Benutzereingaben mit Wiederholungsversuchen
get_user_input() {
    local prompt="$1"          # Die Eingabeaufforderung
    local default="$2"          # Standardwert (optional)
    local validation_func="$3"  # Name der Validierungsfunktion (optional)
    local error_msg="$4"        # Fehlermeldung bei ungültiger Eingabe
    local max_attempts=3        # Maximale Anzahl an Versuchen
    local attempts=0
    local input=""

    # Wenn ein Default-Wert vorhanden ist, in die Eingabeaufforderung einbauen
    if [ -n "$default" ]; then
        prompt="$prompt [$default]: "
    else
        prompt="$prompt: "
    fi

    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        read -rp "$prompt" input

        # Wenn Eingabe leer ist und Default-Wert vorhanden, Default-Wert verwenden
        if [ -z "$input" ] && [ -n "$default" ]; then
            input="$default"
        fi

        # Wenn keine Validierungsfunktion angegeben wurde oder die Validierung erfolgreich ist
        if [ -z "$validation_func" ] || $validation_func "$input"; then
            # Gültige Eingabe
            if [ -n "$input" ]; then
                echo "$input"
                return 0
            fi
        fi

        # Ungültige Eingabe
        warning "$error_msg Versuch $attempts von $max_attempts."

        if [ $attempts -eq $max_attempts ]; then
            error "Maximale Anzahl an Versuchen erreicht. Abbruch."
            return 1
        fi
    done
}

# --- Standard-Validierungsfunktionen ---

# Prüft, ob die Eingabe nicht leer ist
is_not_empty() {
    [[ -n "$1" ]]
}

# Prüft, ob die Eingabe ein gültiger Hostname ist
is_valid_hostname() {
    local hostname="$1"
    # Prüfe ob die Eingabe nicht leer ist und dem Format einer Domain entspricht
    [[ -n "$hostname" ]] && echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$'
}

# Prüft, ob die Eingabe eine gültige IP-Adresse oder Hostname ist
is_valid_ip_or_hostname() {
    local input="$1"
    # Einfache Prüfung ob die Eingabe nicht leer ist und kein Leerzeichen enthält
    [[ -n "$input" ]] && [[ ! "$input" =~ [[:space:]] ]]
}

# Prüft, ob die Eingabe eine gültige Email-Adresse ist
is_valid_email() {
    local email="$1"
    [[ -n "$email" ]] && echo "$email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
}

# Prüft, ob die Eingabe eine Zahl ist
is_number() {
    local num="$1"
    [[ -n "$num" ]] && [[ "$num" =~ ^[0-9]+$ ]]
}

# Prüft, ob die Eingabe ein gültiger Port ist (1-65535)
is_valid_port() {
    local port="$1"
    [[ -n "$port" ]] && [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# Prüft, ob die Antwort ja/nein ist (j/n/J/N)
is_yes_no() {
    local answer="$1"
    [[ -n "$answer" ]] && [[ "$answer" =~ ^[jJnN]$ ]]
}