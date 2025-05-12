#!/bin/bash

# Dateiname für die Ausgabe
output_file="homebrew_detailed_analysis.txt"

# Lösche die Datei, falls sie bereits existiert
> "$output_file"

# Funktion zum Hinzufügen von Trennlinien
add_separator() {
    echo "----------------------------------------" >> "$output_file"
}

# Hole alle manuell installierten Pakete
packages=$(brew leaves)

# Iteriere durch jedes Paket
for package in $packages
do
    echo "Analysiere Paket: $package" >> "$output_file"
    add_separator

    # Paketinformationen
    echo "Paketinformationen:" >> "$output_file"
    brew info "$package" >> "$output_file"
    add_separator

    # Abhängigkeiten des Pakets
    echo "Abhängigkeiten von $package:" >> "$output_file"
    brew deps "$package" >> "$output_file"
    add_separator

    # Pakete, die von diesem Paket abhängen
    echo "Pakete, die $package verwenden:" >> "$output_file"
    brew uses --installed "$package" >> "$output_file"
    add_separator

    # Installationsdatum und -pfad
    echo "Installationsdetails:" >> "$output_file"
    ls -l "$(brew --cellar)/$package" >> "$output_file"
    add_separator

    # Konfigurationsdateien (falls vorhanden)
    echo "Konfigurationsdateien (falls vorhanden):" >> "$output_file"
    find "$(brew --prefix)/etc" -name "*$package*" 2>/dev/null >> "$output_file"
    add_separator

    # Zuletzt verwendete Dateien
    echo "Zuletzt verwendete Dateien:" >> "$output_file"
    find "$(brew --cellar)/$package" -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -5 >> "$output_file"
    add_separator

    echo "" >> "$output_file"
done

echo "Gesamtübersicht aller Abhängigkeiten:" >> "$output_file"
add_separator
brew deps --installed --tree >> "$output_file"

echo "Analyse abgeschlossen. Ergebnisse wurden in $output_file gespeichert."