#!/usr/bin/env bash
#
# nc10-server - Connessione SSH rapida al server domestico
# Uso:  nc10-server
#

# ============================================================
# CONFIGURAZIONE - modifica con i dati del tuo server Ubuntu
# ============================================================
SERVER_IP="192.168.1.XX"       # <-- IP del server (meglio se fisso/prenotato nel modem)
SERVER_USER="tuo-utente"       # <-- utente sul server
# ============================================================

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

echo "[OK] Server raggiungibile, mi connetto..."
exec ssh "$SERVER_USER@$SERVER_IP"
