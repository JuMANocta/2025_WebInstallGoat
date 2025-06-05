#!/bin/bash
set -eu

# 1. Vérifie que le script n'est pas lancé en root
if [ "$EUID" -eq 0 ]; then
    echo "Erreur : Ne lance pas ce script en root. Utilise un utilisateur normal (sudo sera utilisé si besoin)."
    exit 1
fi

# 2. Variables
WEBGOAT_DIR="$(pwd)"
JAR="$WEBGOAT_DIR/webgoat-2025.3.jar"
LOG="$WEBGOAT_DIR/webgoat.log"
JAVA_DIR="/opt/jdk/jdk-24.0.1"
JAVA_BIN="$JAVA_DIR/bin/java"
BASHRC=~/.bashrc
RC_MODIF=0

# 3. Téléchargement de WebGoat si besoin
echo "== Vérification WebGoat =="
if [ ! -f "$JAR" ]; then
    echo "Téléchargement du JAR WebGoat..."
    wget -O "$JAR" https://github.com/WebGoat/WebGoat/releases/download/v2025.3/webgoat-2025.3.jar
else
    echo "WebGoat déjà téléchargé ($JAR)"
fi

# 4. Installation de Java 24 uniquement si absent
echo "== Vérification Java 24 =="
if [ ! -x "$JAVA_BIN" ]; then
    echo "Java 24 absent, installation en cours..."
    if [ ! -f openjdk-24.0.1_linux-x64_bin.tar.gz ]; then
        wget -O openjdk-24.0.1_linux-x64_bin.tar.gz https://download.java.net/java/GA/jdk24.0.1/24a58e0e276943138bf3e963e6291ac2/9/GPL/openjdk-24.0.1_linux-x64_bin.tar.gz
    else
        echo "Archive Java déjà présente."
    fi
    sudo mkdir -p /opt/jdk
    sudo tar -xzf openjdk-24.0.1_linux-x64_bin.tar.gz -C /opt/jdk
    sudo ln -sfn /opt/jdk/jdk-24.0.1 /opt/jdk/current
    echo "Java 24 installé."
else
    echo "Java 24 déjà installé ($JAVA_BIN)"
fi

# 5. Ajout des variables d'environnement seulement si absent
echo "== Configuration des variables d'environnement =="
if ! grep -q '^export JAVA_HOME=/opt/jdk/current' "$BASHRC"; then
    echo 'export JAVA_HOME=/opt/jdk/current' >> "$BASHRC"
    echo "JAVA_HOME ajouté à $BASHRC"
    RC_MODIF=1
else
    echo "JAVA_HOME déjà présent dans $BASHRC"
fi
if ! grep -q '^export PATH=\$JAVA_HOME/bin:\$PATH' "$BASHRC"; then
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$BASHRC"
    echo "Ajout PATH JAVA_HOME dans $BASHRC"
    RC_MODIF=1
else
    echo "PATH JAVA_HOME déjà présent dans $BASHRC"
fi
if ! grep -q '^export TZ=Europe/Paris' "$BASHRC"; then
    echo 'export TZ=Europe/Paris' >> "$BASHRC"
    echo "TZ ajouté à $BASHRC"
    RC_MODIF=1
else
    echo "TZ déjà présent dans $BASHRC"
fi

# 6. Ajout des alias seulement si absent
echo "== Ajout des alias WebGoat dans $BASHRC =="
if ! grep -q "alias webgoat=" "$BASHRC"; then
    echo "alias webgoat='java -jar \"$JAR\" --server.address=0.0.0.0 --webgoat.port=8001 --webwolf.port=8002 > \"$LOG\" 2>&1 < /dev/null &'" >> "$BASHRC"
    echo "Alias 'webgoat' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat' déjà présent."
fi
if ! grep -q "alias webgoat-log=" "$BASHRC"; then
    echo "alias webgoat-log='tail -f \"$LOG\"'" >> "$BASHRC"
    echo "Alias 'webgoat-log' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat-log' déjà présent."
fi
if ! grep -q "alias webgoat-kill=" "$BASHRC"; then
    echo "alias webgoat-kill=\"pkill -f 'webgoat-2025.3.jar'\"" >> "$BASHRC"
    echo "Alias 'webgoat-kill' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat-kill' déjà présent."
fi
if ! grep -q "alias webgoat-status=" "$BASHRC"; then
    echo "alias webgoat-status=\"ps aux | grep '[w]ebgoat-2025.3.jar' && echo 'WebGoat est lancé !' || echo 'WebGoat ne tourne pas.'\"" >> "$BASHRC"
    echo "Alias 'webgoat-status' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat-status' déjà présent."
fi
if ! grep -q "alias webgoat-ip=" "$BASHRC"; then
    echo "alias webgoat-ip='if command -v ifconfig &>/dev/null; then ifconfig | awk \"/flags=/ {iface=\\\$1} /inet / && iface!=\\\"lo:\\\" {print \\\$2; exit}\"; else echo \"ifconfig non dispo\"; fi'" >> "$BASHRC"
    echo "Alias 'webgoat-ip' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat-ip' déjà présent."
fi
if ! grep -q "alias webgoat-help=" "$BASHRC"; then
    echo "alias webgoat-help=\"echo -e 'Alias WebGoat disponibles :\\n  webgoat         - Lancer WebGoat\\n  webgoat-log     - Logs WebGoat\\n  webgoat-kill    - Stopper WebGoat\\n  webgoat-status  - Status WebGoat\\n  webgoat-ip      - Afficher IP locale\\n  webgoat-help    - Cette aide'\"" >> "$BASHRC"
    echo "Alias 'webgoat-help' ajouté."
    RC_MODIF=1
else
    echo "Alias 'webgoat-help' déjà présent."
fi

# 7. Recharge bashrc seulement si modifié
if [ "$RC_MODIF" -eq 1 ]; then
    echo "== Recharge le bashrc pour les alias (nouveau terminal conseillé) =="
    source "$BASHRC"
else
    echo "Aucune modification à apporter à $BASHRC, rechargement non nécessaire."
fi

# 8. Vérifier/installer net-tools (ifconfig)
echo "== Vérification net-tools (ifconfig) =="
if ! command -v ifconfig &> /dev/null; then
    echo "Le paquet net-tools (ifconfig) n'est pas installé. Installation en cours..."
    sudo apt-get update && sudo apt-get install -y net-tools
else
    echo "net-tools déjà installé."
fi

# 9. Affichage IP locale
IP=$(ifconfig | awk '/flags=/ {iface=$1} /inet / && iface!="lo:" {print $2; exit}')

# 10. Fin installation
clear

echo " __        __   _      ____             _    "
echo " \ \      / /__| |__  / ___| ___   __ _| |_  "
echo "  \ \ /\ / / _ \ '_ \| |  _ / _ \ / _\` | __|"
echo "   \ V  V /  __/ |_) | |_| | (_) | (_| | |_  "
echo "    \_/\_/ \___|_.__/ \____|\___/ \__,_|\__| "
echo "        ------------>IDEMPOTENT INSTALL 2025 "
echo "=== Installation terminée ==="
echo "Alias disponibles :"
echo "  webgoat         # Lance WebGoat en arrière-plan (logs dans webgoat.log)"
echo "  webgoat-log     # Affiche les logs temps réel de WebGoat"
echo "  webgoat-kill    # Arrête WebGoat proprement"
echo "  webgoat-status  # Vérifie si WebGoat est lancé"
echo "  webgoat-ip      # Affiche l'adresse IP locale pour l'accès"
echo "  webgoat-help    # Affiche cette liste d'alias"
if [[ -n "$IP" ]]; then
    echo "Puis accède à WebGoat depuis ton navigateur :"
    echo "  http://$IP:8001/WebGoat"
else
    echo "Aucune IP locale trouvée automatiquement, utilise la commande 'webgoat-ip' après l'installation."
fi
