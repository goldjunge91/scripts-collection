#!/bin/bash

# --- Konfiguration ---
# --- WICHTIG: Passe dies an den korrekten Mount-Point deines externen Laufwerks an ---
MOUNT_POINT="/Volumes/TimeMachine"
# --- Du kannst den Laufwerksnamen zur besseren Lesbarkeit anpassen ---
LAUFWERKSNAME="Time Machine" # Kürzerer Name
# --- Schwellenwert für Warnung (in Prozent) ---
SCHWELLENWERT_PROZENT=90

# --- 1. Prüfung: Ist das Laufwerk überhaupt gemountet? ---
# `mount | grep -q ...` sucht nach dem exakten Mount-Eintrag.
# Der Exit-Code ist 0, wenn gefunden, 1 wenn nicht gefunden.
# Wir wollen weitermachen, wenn es GEFUNDEN wird (Exit-Code 0).
if ! mount | grep -q " on ${MOUNT_POINT} "; then
  # Nicht gemountet: Still beenden (Exit-Code 0 = Erfolg, da kein Fehler vorliegt)
  # Optional: Eine Meldung nur im Terminal-Log, falls gewünscht (wird in Automator nicht angezeigt)
  # echo "Info: Laufwerk ${LAUFWERKSNAME} (${MOUNT_POINT}) nicht gemountet. Prüfung übersprungen." >&2
  exit 0
fi

# --- Laufwerk ist gemountet, fahre fort ---
echo "Starte Prüfung für ${LAUFWERKSNAME} unter ${MOUNT_POINT}..." # Terminal-Ausgabe bleibt

# Speicherbelegung holen (Fehler von df unterdrücken, falls Mount Point zwischendurch verschwindet)
df_ausgabe_prozent=$(df -Ph "$MOUNT_POINT" 2>/dev/null | awk 'NR==2 {print $5}')
genutzte_prozent=$(echo "$df_ausgabe_prozent" | tr -d '%')
echo "Debug: Roher Prozentwert von df: '$df_ausgabe_prozent'"      # Terminal-Ausgabe bleibt
echo "Debug: Berechnete genutzte Prozent: '$genutzte_prozent'" # Terminal-Ausgabe bleibt

# Variablen für die finale Benachrichtigung initialisieren
nachricht_titel=""
nachricht_text=""
nachricht_sound=""
nachricht_subtitle="Pfad: ${MOUNT_POINT}" # Subtitle immer anzeigen

# Prüfen, ob genutzte_prozent eine gültige Zahl ist
if [[ "$genutzte_prozent" =~ ^[0-9]+$ ]]; then
  # Zahl ist gültig, Status bestimmen (Warnung oder OK)
  if [[ "$genutzte_prozent" -ge "$SCHWELLENWERT_PROZENT" ]]; then
    # Status: Warnung
    nachricht_titel="⚠️ ${LAUFWERKSNAME} Warnung"
    nachricht_text="${genutzte_prozent}% belegt (Hoch)" # Präziser Text
    nachricht_sound="Frog"
    echo "Warnung: ${nachricht_text}" # Terminal-Ausgabe
  else
    # Status: OK
    nachricht_titel="✅ ${LAUFWERKSNAME} OK"
    nachricht_text="${genutzte_prozent}% belegt" # Präziser Text
    nachricht_sound="Glass"
    echo "Erfolg: ${nachricht_text}" # Terminal-Ausgabe
  fi
else
  # Fehler: Wert konnte nicht ermittelt werden (df fehlgeschlagen oder gab Müll zurück)
  nachricht_titel="❌ ${LAUFWERKSNAME} Fehler"
  nachricht_text="Auslastung nicht lesbar" # Präziser Text
  nachricht_sound="Basso"
  echo "Fehler: ${nachricht_text}. Rohwert: '$df_ausgabe_prozent'" >&2 # Terminal-Ausgabe
fi

# Nur EINE Benachrichtigung senden, wenn Titel/Text gesetzt wurden
if [[ -n "$nachricht_titel" ]]; then
  osascript -e "display notification \"${nachricht_text}\" with title \"${nachricht_titel}\" subtitle \"${nachricht_subtitle}\" sound name \"${nachricht_sound}\""
fi

echo "Prüfung für ${LAUFWERKSNAME} beendet." # Terminal-Ausgabe bleibt
