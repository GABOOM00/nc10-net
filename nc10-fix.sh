#!/usr/bin/env bash
#
# nc10-fix — Diagnosi e riparazione automatica dei problemi di rete
# Risolve: reti sovrapposte, "Device or resource busy", residui di Ceni,
#          gestori di rete concorrenti, IP doppi sulle interfacce.
# Uso:  sudo nc10-fix
#

. /usr/local/lib/nc10-lib.sh || { echo "Libreria nc10-lib mancante: rilancia install.sh"; exit 1; }

richiedi_root

DA_MENU=0
[ "$1" = "--da-menu" ] && DA_MENU=1

INTERFACES="/etc/network/interfaces"
BACKUP="/etc/network/interfaces.backup-nc10"
PROBLEMI=0

echo ""
echo "========================================"
echo "   NC10 — Diagnosi e riparazione rete"
echo "========================================"

# --- 1) Processi di rete duplicati/sovrapposti ---
info "1/5 Controllo processi di rete sovrapposti..."
N_WPA=$(pgrep -c wpa_supplicant 2>/dev/null || echo 0)
N_DHC=$(pgrep -c dhclient 2>/dev/null || echo 0)
if [ "$N_WPA" -gt 0 ] || [ "$N_DHC" -gt 0 ]; then
    echo "    Trovati: $N_WPA wpa_supplicant, $N_DHC dhclient attivi. Li chiudo."
    pulisci_connessioni
    PROBLEMI=$((PROBLEMI + 1))
    ok "Processi chiusi."
else
    ok "Nessun processo sovrapposto."
fi

# --- 2) Gestori di rete concorrenti (NetworkManager, connman) ---
info "2/5 Controllo gestori di rete concorrenti..."
CONCORRENTI=0
for gestore in NetworkManager connman connmand wicd; do
    if pgrep -x "$gestore" >/dev/null 2>&1; then
        echo "    Trovato $gestore attivo: lo fermo (fino al prossimo riavvio)."
        service "$gestore" stop 2>/dev/null || killall "$gestore" 2>/dev/null
        CONCORRENTI=1
        PROBLEMI=$((PROBLEMI + 1))
    fi
done
if [ "$CONCORRENTI" -eq 0 ]; then
    ok "Nessun gestore concorrente attivo."
else
    ok "Gestori concorrenti fermati."
fi

# --- 3) Residui di Ceni in /etc/network/interfaces ---
info "3/5 Controllo configurazioni residue di Ceni..."
if [ -f "$INTERFACES" ] && grep -Eq '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+(wlan|eth|enp|usb)' "$INTERFACES"; then
    if [ ! -f "$BACKUP" ]; then
        cp "$INTERFACES" "$BACKUP"
        echo "    Backup salvato in: $BACKUP"
    fi
    # Commento (con #nc10#) tutte le righe che attivano interfacce
    # diverse dal loopback: sono loro a creare connessioni doppie al boot.
    sed -i -E 's/^([[:space:]]*(auto|allow-hotplug|iface|wpa-|address|netmask|gateway|dns-)[^#]*)$/#nc10# \1/' "$INTERFACES"
    # Ripristino le righe del loopback, che deve restare attivo
    sed -i -E 's/^#nc10# ([[:space:]]*(auto|iface)[[:space:]]+lo.*)$/\1/' "$INTERFACES"
    PROBLEMI=$((PROBLEMI + 1))
    ok "Configurazioni di Ceni neutralizzate (commentate, non cancellate)."
    echo "    Per ripristinarle: sudo cp $BACKUP $INTERFACES"
else
    ok "Nessuna configurazione residua trovata."
fi

# --- 4) Reset delle interfacce (IP doppi, stato incastrato) ---
info "4/5 Resetto le interfacce di rete..."
for iface in $(ip -o link | awk -F': ' '{print $2}' | grep -v '^lo$'); do
    ip addr flush dev "$iface" 2>/dev/null
    ip link set "$iface" down 2>/dev/null
done
sleep 1
rfkill unblock all 2>/dev/null || true
WIFI=$(trova_interfaccia_wifi)
[ -n "$WIFI" ] && ip link set "$WIFI" up && sleep 2
ok "Interfacce ripulite."

# --- 5) Verifica finale ---
info "5/5 Verifica finale..."
if [ -n "$WIFI" ]; then
    if iw "$WIFI" scan >/dev/null 2>&1; then
        ok "La scheda WiFi ($WIFI) risponde e riesce a scansionare."
    else
        err "La scheda WiFi risponde ancora male. Prova a riavviare il computer."
    fi
else
    err "Nessuna interfaccia WiFi trovata (scheda spenta o driver mancante)."
fi

echo ""
echo "========================================"
if [ "$PROBLEMI" -gt 0 ]; then
    ok "Riparazione completata: risolti $PROBLEMI problemi."
else
    ok "Nessun problema trovato: la rete era gia' pulita."
fi
echo "========================================"

# Se lanciato da solo, offro di aprire il menu di connessione
if [ "$DA_MENU" -eq 0 ]; then
    echo ""
    read -rp "Vuoi aprire ora il menu di connessione (nc10-net)? [s/n]: " apri
    if [ "$apri" = "s" ] || [ "$apri" = "S" ]; then
        exec /usr/local/bin/nc10-net
    fi
fi
