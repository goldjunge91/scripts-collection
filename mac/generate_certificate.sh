#!/bin/bash

# Zertifikatsinformationen
COUNTRY="DE"
STATE="Bayern"
LOCALITY="München"
ORGANIZATION="Meine Firma"
UNIT="IT-Abteilung"
COMMON_NAME="mein-nas.lokal"
EMAIL="ihr@email.com"

# Ausgabeverzeichnis
OUTPUT_DIR="./zertifikate"

# Zertifikatsdateinamen
CERT_FILE="own_signed-xyz-tool.crt"
KEY_FILE="own_signed-xyz-tool.key"

# Ausgabeverzeichnis erstellen, falls es nicht existiert
mkdir -p "$OUTPUT_DIR"

# Zertifikat und Schlüssel generieren
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$OUTPUT_DIR/$KEY_FILE" -out "$OUTPUT_DIR/$CERT_FILE" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

echo "Zertifikat und Schlüssel erfolgreich generiert:"
echo "- $OUTPUT_DIR/$CERT_FILE"
echo "- $OUTPUT_DIR/$KEY_FILE"