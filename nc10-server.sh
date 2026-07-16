#!/usr/bin/env bash
#
# nc10-server - Connessione SSH rapida al server domestico
# Uso:  nc10-server          (connessione normale)
#       nc10-server setup    (una tantum: configura il server per il prompt adattivo)
#
# Se il terminale locale e' datato (ROXTerm senza Nerd Font), avvisa il
# server con la variabile NC10_CLIENT=1 cosi' il server usa un prompt
# semplice invece di Starship. Da terminali moderni (Termius, ecc.)
# Starship resta attivo.
#

# ============================================================
# CONFIGURAZIONE - modifica con i dati del tuo server Ubuntu
# ============================================================
SERVER_IP="192.168.1.XX"       # <-- IP del server (meglio se fisso/prenotato nel modem)
SERVER_USER="tuo-utente"       # <-- utente sul server
# ============================================================

# Uso il rilevamento del terminale della libreria condivisa, se presente
if [ -f /usr/local/lib/nc10-lib.sh ]; then
    . /usr/local/lib/nc10-lib.sh
fi

if ! command -v ssh >/dev/null 2>&1; then
    echo "[ERRORE] Client SSH non installato. Installa con:"
    echo "    sudo apt install openssh-client"
    exit 1
fi

echo "[...] Verifico che il server $SERVER_IP risponda..."
if ! ping -c 1 -W 3 "$SERVER_IP" >/dev/null 2>&1; then
    echo "[ERRORE] Il server non risponde. Controlla che:"
    echo "  - l'NC10 sia connesso alla rete di casa (lancia: sudo nc10-net)"
    echo "  - il server sia acceso"
    echo "  - l'IP in cima a questo script sia giusto (sudo nano /usr/local/bin/nc10-server)"
    exit 1
fi

# ---------- setup: prepara il server (una volta sola) ----------
if [ "$1" = "setup" ]; then
    echo "[...] Configuro il server per il prompt adattivo..."
    ssh "$SERVER_USER@$SERVER_IP" 'bash -s' << 'EOF'
# Backup del .bashrc, solo la prima volta
if [ ! -f ~/.bashrc.backup-nc10 ]; then
    cp ~/.bashrc ~/.bashrc.backup-nc10
    echo "[OK] Backup creato: ~/.bashrc.backup-nc10"
fi
# Rendo condizionale l'avvio di Starship (idempotente: non lo rifa' due volte)
if grep -q 'NC10_CLIENT' ~/.bashrc; then
    echo "[OK] Il server era gia' configurato: niente da fare."
elif grep -q 'starship init' ~/.bashrc; then
    sed -i 's|^[[:space:]]*eval "\$(starship init bash)"|[ -z "$NC10_CLIENT" ] \&\& eval "$(starship init bash)"|' ~/.bashrc
    echo "[OK] Starship ora si avvia solo per i terminali moderni."
    echo "     Per tornare indietro: cp ~/.bashrc.backup-nc10 ~/.bashrc"
else
    echo "[ATTENZIONE] Non ho trovato la riga di Starship in ~/.bashrc."
    echo "             Se usi zsh o un altro file, dimmelo e adattiamo."
fi
EOF
    echo ""
    echo "[OK] Setup completato. Ora usa semplicemente: nc10-server"
    exit 0
fi

# ---------- connessione normale ----------
if command -v terminale_moderno >/dev/null 2>&1 && terminale_moderno; then
    # Terminale moderno: sessione normale, Starship attivo sul server
    echo "[OK] Server raggiungibile, mi connetto (prompt completo)..."
    exec ssh "$SERVER_USER@$SERVER_IP"
else
    # Terminale datato (ROXTerm senza Nerd Font): avviso il server
    echo "[OK] Server raggiungibile, mi connetto (prompt semplice per questo terminale)..."
    exec ssh -t "$SERVER_USER@$SERVER_IP" "export NC10_CLIENT=1; exec bash -l"
fi
