#!/usr/bin/env bash
#
# install.sh — Installa nc10-net, nc10-set, nc10-fix, nc10-server
# Uso:  sudo ./install.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[ERRORE] Lancia l'installer con sudo:"
    echo "    sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTENTE="${SUDO_USER:-$USER}"

echo "== Installazione nc10-net =="

# 1) Libreria condivisa
mkdir -p /usr/local/lib
cp "$SCRIPT_DIR/nc10-lib.sh" /usr/local/lib/nc10-lib.sh
echo "[OK] Libreria installata"

# 2) Comandi
for nome in nc10-net nc10-set nc10-fix nc10-server gaboom; do
    if [ -f "$SCRIPT_DIR/$nome.sh" ]; then
        cp "$SCRIPT_DIR/$nome.sh" "/usr/local/bin/$nome"
        chmod +x "/usr/local/bin/$nome"
        echo "[OK] Comando installato: $nome"
    fi
done

# 3) Sudo senza password SOLO per i tre comandi di rete,
#    così l'avvio automatico e le riparazioni non chiedono la password.
cat > /etc/sudoers.d/nc10-net <<EOF
$UTENTE ALL=(root) NOPASSWD: /usr/local/bin/nc10-net, /usr/local/bin/nc10-set, /usr/local/bin/nc10-fix
EOF
chmod 440 /etc/sudoers.d/nc10-net
echo "[OK] Regola sudo creata (solo per nc10-net, nc10-set, nc10-fix)"

# 4) Avvio automatico al login (apre un terminale con il menu)
AUTOSTART_DIR="/home/$UTENTE/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

TERMINALE=""
for t in roxterm lxterminal xfce4-terminal gnome-terminal xterm; do
    if command -v "$t" >/dev/null 2>&1; then
        TERMINALE="$t"
        break
    fi
done

if [ -z "$TERMINALE" ]; then
    echo "[ATTENZIONE] Nessun terminale grafico trovato: salto l'avvio automatico."
    echo "             Potrai comunque usare il comando: sudo nc10-net"
else
    case "$TERMINALE" in
        gnome-terminal) CMD="gnome-terminal -- sudo /usr/local/bin/nc10-net" ;;
        *)              CMD="$TERMINALE -e sudo /usr/local/bin/nc10-net" ;;
    esac

    cat > "$AUTOSTART_DIR/nc10-net.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=NC10 Net
Comment=Menu di connessione all'avvio
Exec=$CMD
X-GNOME-Autostart-enabled=true
EOF
    chown -R "$UTENTE:$UTENTE" "$AUTOSTART_DIR"
    echo "[OK] Avvio automatico impostato (terminale: $TERMINALE)"
fi

echo ""
echo "== Fatto! =="
echo ""
echo "PROSSIMI PASSI:"
echo "  1) Ripara eventuali pasticci di rete:   sudo nc10-fix"
echo "  2) Imposta la tua rete di sistema:      sudo nc10-set"
echo "  3) Connettiti quando vuoi:              sudo nc10-net"
echo "  4) (Opzionale) Configura il server SSH: sudo nano /usr/local/bin/nc10-server"
echo ""
echo "Per rivedere in qualsiasi momento l'elenco dei comandi:  gaboom help"
echo ""
echo "Al prossimo riavvio il menu di connessione apparirà da solo."
