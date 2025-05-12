#!/bin/bash

output_file="homebrew_detailed_analysis_v2.txt"
> "$output_file"

add_separator() {
    echo "----------------------------------------" >> "$output_file"
}

# Funktion für den Fortschrittsbalken
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    printf "\rFortschritt: [%${completed}s%${remaining}s] %d%%" | tr ' ' '#' | tr '#' ' '
    printf " (%d von %d)" "$current" "$total"
}

packages=$(brew leaves)
total_packages=$(echo "$packages" | wc -w)
current=0

echo "Starte Analyse von $total_packages Paketen..."

for package in $packages
do
    current=$((current + 1))
    progress_bar $current $total_packages

    echo "Analysiere Paket: $package" >> "$output_file"
    add_separator

    echo "Paketinformationen:" >> "$output_file"
    brew info "$package" >> "$output_file"
    add_separator

    echo "Abhängigkeiten von $package:" >> "$output_file"
    brew deps "$package" >> "$output_file"
    add_separator

    echo "Pakete, die $package verwenden:" >> "$output_file"
    brew uses --installed "$package" >> "$output_file"
    add_separator

    echo "Installationsdetails:" >> "$output_file"
    ls -l "$(brew --cellar)/$package" >> "$output_file"
    add_separator

    echo "Konfigurationsdateien (falls vorhanden):" >> "$output_file"
    find "$(brew --prefix)/etc" -name "*$package*" 2>/dev/null >> "$output_file"
    add_separator

    echo "Zuletzt verwendete Dateien:" >> "$output_file"
    find "$(brew --cellar)/$package" -type f -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -rn | head -5 >> "$output_file"
    add_separator

    echo "" >> "$output_file"
done

echo -e "\nErstelle Gesamtübersicht aller Abhängigkeiten..."
echo "Gesamtübersicht aller Abhängigkeiten:" >> "$output_file"
add_separator
brew deps --installed --tree >> "$output_file"

echo -e "\nAnalyse abgeschlossen. Ergebnisse wurden in $output_file gespeichert."
