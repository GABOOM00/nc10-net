#!/usr/bin/env bash
#
# nc10-net — Selettore di connessione per Samsung NC10 (wpa_supplicant)
# Menu all'avvio: casa (Vodafone), telefono via cavo USB, o nuova rete WiFi.
#
# Requisiti: wpa_supplicant, wpa_cli, dhclient, iw
#

# ============================================================
# CONFIGURAZIONE — modifica queste due righe con i tuoi dati
# ============================================================
HOME_SSID="Vodafone-XXXXXX"      # <-- nome esatto della tua WiFi di casa
HOME_PASS="TUA-PASSWORD"          # <-- password della rete di casa
# ============================================================

VERDE='\033[0;32m'; ROSSO='\033[0;31m'; GIALLO='\033[1;33m'; RESET='\033[0m'
WPA_CONFIG="/etc/wpa_supplicant/wpa_supplicant.conf"

ok()   { echo -e "${VERDE}[OK]${RESET} $1"; }
err()  { echo -e "${ROSSO}[ERRORE]${RESET} $1"; }
info() { echo -e "${GIALLO}[...]${RESET} $1"; }

controlla_permessi() {
    if [ "$EUID" -ne 0 ]; then
        err "Questo script richiede sudo. Riavvia con:"
        echo "    sudo nc10-net"
        exit 1
    fi
}

trova_interfaccia_wifi() {
    # Cerca l'interfaccia WiFi (wlan0, wlp2s0, ecc.)
    iw dev | grep "Interface" | head -n1 | awk '{print $NF}'
}

trova_interfaccia_usb() {
    # Cerca interfaccia USB (usb0, enp0s...)
    ip link | grep -E '^\d+: (usb|enp[0-9]+s[0-9]+u)' | head -n1 | awk -F: '{print $2}' | xargs
}

abilita_wifi() {
    info "Abilito il WiFi..."
    rfkill unblock wlan 2>/dev/null || true
    ip link set "$1" up
    sleep 2
}

connetti_casa() {
    local wifi=$(trova_interfaccia_wifi)
    if [ -z "$wifi" ]; then
        err "Nessuna interfaccia WiFi trovata."
        return 1
    fi

    abilita_wifi "$wifi"
    info "Cerco la rete $HOME_SSID..."
    iw "$wifi" scan | grep -q "$HOME_SSID" || {
        err "Rete $HOME_SSID non trovata."
        return 1
    }

    # Creo un profilo temporaneo per la connessione
    local temp_conf="/tmp/wpa_temp.conf"
    wpa_passphrase "$HOME_SSID" "$HOME_PASS" > "$temp_conf"

    info "Mi connetto a $HOME_SSID..."
    wpa_supplicant -B -i "$wifi" -D nl80211,wext -c "$temp_conf"
    sleep 3

    info "Richiedo un indirizzo IP..."
    dhclient -v "$wifi"
    
    test_connessione
    rm -f "$temp_conf"
}

connetti_telefono() {
    echo ""
    echo "  1. Collega il telefono al computer con il cavo USB"
    echo "  2. Sul telefono attiva: Impostazioni > Hotspot e tethering > Tethering USB"
    echo ""
    read -rp "Quando hai fatto, premi INVIO..."

    info "Cerco l'interfaccia USB..."
    local usb=$(trova_interfaccia_usb)
    local tentativo=1
    while [ -z "$usb" ] && [ $tentativo -le 6 ]; do
        sleep 2
        usb=$(trova_interfaccia_usb)
        tentativo=$((tentativo + 1))
    done

    if [ -z "$usb" ]; then
        err "Nessuna interfaccia USB trovata."
        err "Verifica che il tethering USB sia attivo sul telefono."
        return 1
    fi

    info "Trovata interfaccia: $usb"
    ip link set "$usb" up
    sleep 1

    info "Richiedo un indirizzo IP su $usb..."
    dhclient -v "$usb"
    test_connessione
}

connetti_nuova_rete() {
    local wifi=$(trova_interfaccia_wifi)
    if [ -z "$wifi" ]; then
        err "Nessuna interfaccia WiFi trovata."
        return 1
    fi

    abilita_wifi "$wifi"
    
    info "Scansiono le reti disponibili..."
    iw "$wifi" scan > /tmp/scan_output.txt
    
    echo ""
    echo "Reti WiFi trovate:"
    grep "SSID:" /tmp/scan_output.txt | sed 's/.*SSID: /  /'
    echo ""

    read -rp "Nome della rete (SSID): " ssid
    if [ -z "$ssid" ]; then
        err "SSID vuoto, annullo."
        return 1
    fi

    read -rsp "Password (lascia vuoto se la rete è aperta): " pass
    echo ""

    local temp_conf="/tmp/wpa_temp.conf"
    
    if [ -n "$pass" ]; then
        wpa_passphrase "$ssid" "$pass" > "$temp_conf"
    else
        # Rete aperta
        cat > "$temp_conf" <<EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi

    info "Mi connetto a \"$ssid\"..."
    wpa_supplicant -B -i "$wifi" -D nl80211,wext -c "$temp_conf"
    sleep 3

    info "Richiedo un indirizzo IP..."
    dhclient -v "$wifi"
    
    if test_connessione; then
        ok "Connessione riuscita!"
        # Salvo la rete (opzionale: aggiungi a wpa_supplicant.conf)
    else
        err "Connessione a \"$ssid\" fallita."
    fi
    
    rm -f "$temp_conf"
}

test_connessione() {
    info "Verifico la connessione a internet..."
    sleep 3
    if ping -c 2 -W 4 1.1.1.1 >/dev/null 2>&1; then
        ok "Sei connesso a internet!"
        return 0
    else
        err "Rete connessa ma internet non risponde."
        return 1
    fi
}

# ================= MENU PRINCIPALE =================
controlla_permessi

while true; do
    echo ""
    echo "=================================="
    echo "   NC10 — Come vuoi connetterti?"
    echo "=================================="
    echo "  1) WiFi di casa (Vodafone)"
    echo "  2) Telefono via cavo USB"
    echo "  3) Un'altra rete WiFi"
    echo "  4) Non connettermi / Esci"
    echo ""
    read -rp "Scelta [1-4]: " scelta

    case "$scelta" in
        1) connetti_casa && break ;;
        2) connetti_telefono && break ;;
        3) connetti_nuova_rete && break ;;
        4) echo "Ok, nessuna connessione. Ciao!"; break ;;
        *) err "Scelta non valida, riprova." ;;
    esac

    echo ""
    read -rp "Vuoi riprovare? [s/n]: " riprova
    [ "$riprova" != "s" ] && [ "$riprova" != "S" ] && break
done

echo ""
read -rp "Premi INVIO per chiudere..."
