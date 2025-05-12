#!/bin/bash

output_file="homebrew_focused_analysis.txt"
> "$output_file"

add_separator() {
    echo "----------------------------------------" >> "$output_file"
}

show_progress() {
    local current=$1
    local total=$2
    local percentage=$((current * 100 / total))
    printf "\rFortschritt: %d%% (%d von %d)" "$percentage" "$current" "$total"
}

get_install_info() {
    local package=$1
    brew info --json=v2 --installed "$package" | 
    jq -r '.formulae[0] // .casks[0] | 
    (.installed[0].installed_on_request | tostring) + " " + 
    (.installed[0].version // "unbekannt") + " " + 
    (.installed[0].installed_as_dependency | tostring)' 2>/dev/null || 
    echo "unbekannt unbekannt false"
}

packages=$(brew leaves)
total_packages=$(echo "$packages" | wc -w | tr -d ' ')
current=0

echo "Starte Analyse von $total_packages direkt installierten Paketen..."

for package in $packages
do
    current=$((current + 1))
    show_progress $current $total_packages

    echo "Paket: $package" >> "$output_file"
    add_separator

    # Installationsdatum und Version
    install_info=$(get_install_info "$package")
    install_date=$(echo $install_info | cut -d' ' -f1)
    version=$(echo $install_info | cut -d' ' -f2)
    
    if [ "$install_date" != "unbekannt" ]; then
        echo "Installiert am: $(date -r $install_date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Datum nicht verfügbar")" >> "$output_file"
    else
        echo "Installationsdatum: Nicht verfügbar" >> "$output_file"
    fi
    echo "Version: $version" >> "$output_file"

    # Speicherort und Größe
    cellar_path=$(brew --cellar "$package" 2>/dev/null)
    if [ -d "$cellar_path" ]; then
        size=$(du -sh "$cellar_path" 2>/dev/null | cut -f1)
        echo "Speicherort: $cellar_path" >> "$output_file"
        echo "Größe: $size" >> "$output_file"
    else
        echo "Speicherort nicht gefunden" >> "$output_file"
    fi

    # Zuletzt ausgeführte ausführbare Datei
    bin_path="$(brew --prefix)/bin/$package"
    if [ -f "$bin_path" ]; then
        last_executed=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$bin_path" 2>/dev/null)
        echo "Zuletzt ausgeführt: $last_executed" >> "$output_file"
    else
        echo "Keine ausführbare Datei gefunden" >> "$output_file"
    fi

    # Kurze Beschreibung
    description=$(brew info "$package" | sed -n '2p')
    echo "Beschreibung: $description" >> "$output_file"

    echo "" >> "$output_file"
done

echo -e "\nAnalyse abgeschlossen. Ergebnisse wurden in $output_file gespeichert."