#!/usr/bin/env bash
#
# install.sh — Installa nc10-net e lo imposta all'avvio della sessione
# Uso:  ./install.sh   (ti chiederà la password sudo solo per copiare il comando)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== Installazione nc10-net =="

# 1) Copio lo script come comando di sistema
sudo cp "$SCRIPT_DIR/nc10-net.sh" /usr/local/bin/nc10-net
sudo chmod +x /usr/local/bin/nc10-net
echo "[OK] Comando installato: puoi lanciarlo in qualsiasi momento con:  nc10-net"

# 2) Avvio automatico al login (apre un terminale con il menu)
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Trovo un terminale disponibile sul sistema
TERMINALE=""
for t in lxterminal xfce4-terminal gnome-terminal xterm; do
    if command -v "$t" >/dev/null 2>&1; then
        TERMINALE="$t"
        break
    fi
done

if [ -z "$TERMINALE" ]; then
    echo "[ATTENZIONE] Nessun terminale grafico trovato: salto l'avvio automatico."
    echo "             Potrai comunque usare il comando: nc10-net"
else
    case "$TERMINALE" in
        gnome-terminal) CMD="gnome-terminal -- /usr/local/bin/nc10-net" ;;
        xfce4-terminal) CMD="xfce4-terminal -e /usr/local/bin/nc10-net" ;;
        *)              CMD="$TERMINALE -e /usr/local/bin/nc10-net" ;;
    esac

    cat > "$AUTOSTART_DIR/nc10-net.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=NC10 Net
Comment=Menu di connessione all'avvio
Exec=$CMD
X-GNOME-Autostart-enabled=true
EOF
    echo "[OK] Avvio automatico impostato (terminale: $TERMINALE)"
fi

echo ""
echo "== Fatto! =="
echo "IMPORTANTE: apri /usr/local/bin/nc10-net e scrivi il nome della tua"
echo "WiFi di casa nella riga HOME_SSID (ed eventualmente HOME_PASS):"
echo "    sudo nano /usr/local/bin/nc10-net"
echo ""
echo "Al prossimo riavvio il menu apparirà da solo."
