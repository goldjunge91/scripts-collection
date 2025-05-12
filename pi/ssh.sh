#!/bin/bash

# Script zur Konfiguration von SSH-Einstellungen und SSH-Key

# Log-Datei
LOG_FILE="/var/log/ssh-setup.log"
echo "Starte SSH-Konfiguration am $(date)" | tee -a $LOG_FILE


sudo useradd -m -s /bin/bash marco
# sudo passwd marco
sudo usermod -aG sudo marco

sudo mkdir -p /home/marco/.ssh
sudo chmod 700 /home/marco/.ssh

sudo touch /home/username/.ssh/authorized_keys
echo "ssh-rsa ### hier key eintrganen #####################################
" | sudo tee /home/marco/.ssh/authorized_keys
# Berechtigungen setzen
sudo chmod 600 /home/marco/.ssh/authorized_keys
sudo chown -R marco:marco /home/marco/.ssh
# Backup der originalen SSH-Konfiguration
echo "Erstelle Backup der originalen SSH-Konfiguration..." | tee -a $LOG_FILE
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Konfiguriere SSH für bessere Sicherheit
# echo "Konfiguriere SSH für erhöhte Sicherheit..." | tee -a $LOG_FILE
# cat > /etc/ssh/sshd_config << 'EOF'
# # SSH Server Konfiguration
# Port 22
# Protocol 2
# # Authentifizierungseinstellungen
# PermitRootLogin no
# PubkeyAuthentication yes
# PasswordAuthentication no
# PermitEmptyPasswords no
# ChallengeResponseAuthentication no
# UsePAM yes
# # Sicherheitseinstellungen
# X11Forwarding no
# PrintMotd no
# AcceptEnv LANG LC_*
# Subsystem sftp /usr/lib/openssh/sftp-server
# ClientAliveInterval 300
# ClientAliveCountMax 2
# MaxAuthTries 4
# MaxSessions 10
# EOF


# Füge deinen SSH Public Key hinzu - ERSETZE MIT DEINEM TATSÄCHLICHEN SSH PUBLIC KEY
echo "Füge SSH Public Key hinzu..." | tee -a $LOG_FILE
cat > /home/marco/.ssh/authorized_keys << 'EOF'
### hier key eintrganen #####################################EOF
# Setze richtige Berechtigungen
chmod 600 /home/marco/.ssh/authorized_keys
chown -R marco:marco /home/marco/.ssh

# Starte SSH-Dienst neu
echo "Starte SSH-Dienst neu..." | tee -a $LOG_FILE
systemctl restart sshd

# Installiere fail2ban für zusätzliche Sicherheit
# echo "Installiere fail2ban..." | tee -a $LOG_FILE
# apt-get update
# apt-get install fail2ban -y

# # Konfiguriere fail2ban für SSH
# cat > /etc/fail2ban/jail.local << 'EOF'
# [sshd]
# enabled = true
# port = ssh
# filter = sshd
# logpath = /var/log/auth.log
# maxretry = 5
# bantime = 3600
# EOF

# # Starte fail2ban-Dienst
# systemctl restart fail2ban

echo "SSH-Sicherheitsupdate abgeschlossen am $(date)" | tee -a $LOG_FILE
echo "Skript erfolgreich beendet!"
# mutni8mokQ
