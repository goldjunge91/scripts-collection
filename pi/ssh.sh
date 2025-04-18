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
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuZ7c+5p+/ZPxY4S3FEmvw7nhp1hmKfDH0/oslyF2m+yeeGV3ojdcPPN+K+tYpfDP3zzXT7H+4rKsmZ3LzlFrhxu/qZVMkv3x6eEOVA4Yaa/ZEyJO4yMN+9qfgkHREvu6wnSNeDdBIPIhtxtdikumYOEdGNZCl/3D67X8k8kjZdJAGLMXMaw1+B+jThpJs3m+5LJLQDGGT9ptrfjJmjlijNumjZ+7XMXv257VOS5IoiDESETTQMQhFWdeMykjMZKsvIXBcOylGbyIDeVlpdgHDnX9qhrMSceeYieOJO0DdsBJindke5e7A0eAixr+IvQzMCUf8NTLm96tEBPHWchqkga5cexoXkG1egL7kHudm9milSITFoAP87lQkmLq28tpTTLJPhEdCLQMfcsltjFL9RMdIwBHFbdwn/hWbBaAbE4sk/eiGbT1bfefAdC89rBff+ZS+Y5lW9Fuc5rS5RWLe0xjW8a9NO8zIMemRMtpabjuj3NJSLb/Uy9E8sarkaGlbkJPNaFz1y4hDzGlUCzo3UMbMnAa8cUbrN2wGejzHY4Ik2Hp5GDr2fmAphdOrGm/EsR8PRAVJx1Uxm+B8u5Cz2/iAtKI1FBysI/9v5kF/KjLobfljEbVoSsHLd5+pEnjKk02Af7SHp+/HWnXHKrYEZ6cjTabWfM8WU1JNkoKnqQ== tozzi@H3Mistral
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
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuZ7c+5p+/ZPxY4S3FEmvw7nhp1hmKfDH0/oslyF2m+yeeGV3ojdcPPN+K+tYpfDP3zzXT7H+4rKsmZ3LzlFrhxu/qZVMkv3x6eEOVA4Yaa/ZEyJO4yMN+9qfgkHREvu6wnSNeDdBIPIhtxtdikumYOEdGNZCl/3D67X8k8kjZdJAGLMXMaw1+B+jThpJs3m+5LJLQDGGT9ptrfjJmjlijNumjZ+7XMXv257VOS5IoiDESETTQMQhFWdeMykjMZKsvIXBcOylGbyIDeVlpdgHDnX9qhrMSceeYieOJO0DdsBJindke5e7A0eAixr+IvQzMCUf8NTLm96tEBPHWchqkga5cexoXkG1egL7kHudm9milSITFoAP87lQkmLq28tpTTLJPhEdCLQMfcsltjFL9RMdIwBHFbdwn/hWbBaAbE4sk/eiGbT1bfefAdC89rBff+ZS+Y5lW9Fuc5rS5RWLe0xjW8a9NO8zIMemRMtpabjuj3NJSLb/Uy9E8sarkaGlbkJPNaFz1y4hDzGlUCzo3UMbMnAa8cUbrN2wGejzHY4Ik2Hp5GDr2fmAphdOrGm/EsR8PRAVJx1Uxm+B8u5Cz2/iAtKI1FBysI/9v5kF/KjLobfljEbVoSsHLd5+pEnjKk02Af7SHp+/HWnXHKrYEZ6cjTabWfM8WU1JNkoKnqQ== tozzi@H3Mistral
EOF
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