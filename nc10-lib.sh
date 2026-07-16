#!/usr/bin/env bash
#
# nc10-lib — Funzioni comuni per nc10-net, nc10-set, nc10-fix
# Viene installata in /usr/local/lib/nc10-lib.sh
#

CONFIG="/etc/nc10-net.conf"

VERDE='\033[0;32m'; ROSSO='\033[0;31m'; GIALLO='\033[1;33m'; RESET='\033[0m'

ok()   { echo -e "${VERDE}[OK]${RESET} $1"; }
err()  { echo -e "${ROSSO}[ERRORE]${RESET} $1"; }
info() { echo -e "${GIALLO}[...]${RESET} $1"; }

richiedi_root() {
    if [ "$EUID" -ne 0 ]; then
        err "Questo comando richiede i permessi di root. Rilancialo con:"
        echo "    sudo $(basename "$0")"
        exit 1
    fi
}

# ---------- Configurazione "rete di sistema" ----------

leggi_config() {
    TIPO=""; SSID=""; PASS=""
    [ -f "$CONFIG" ] && . "$CONFIG"
}

salva_config() {
    # $1=tipo (wifi|usb|ethernet)  $2=ssid  $3=pass
    cat > "$CONFIG" <<EOF
TIPO="$1"
SSID="$2"
PASS="$3"
EOF
    chmod 600 "$CONFIG"
    ok "Rete di sistema salvata: $1${2:+ ($2)}"
}

# ---------- Interfacce ----------

trova_interfaccia_wifi() {
    iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}'
}

trova_interfaccia_usb() {
    ip -o link | awk -F': ' '$2 ~ /^(usb|enp[0-9]+s[0-9]+u)/ {print $2; exit}'
}

trova_interfaccia_ethernet() {
    ip -o link | awk -F': ' '$2 ~ /^(eth|enp)/ && $2 !~ /u/ {print $2; exit}'
}

# ---------- Pulizia (evita reti sovrapposte e "Device busy") ----------

pulisci_connessioni() {
    killall wpa_supplicant 2>/dev/null
    killall dhclient 2>/dev/null
    sleep 1
}

resetta_interfaccia() {
    # $1 = interfaccia
    ip addr flush dev "$1" 2>/dev/null
    ip link set "$1" down 2>/dev/null
    sleep 1
    rfkill unblock wlan 2>/dev/null || true
    ip link set "$1" up 2>/dev/null
    sleep 2
}

# ---------- Scansione WiFi ----------

scansiona_reti() {
    # $1 = interfaccia. Riempie l'array globale RETI.
    RETI=()
    local tentativo output
    for tentativo in 1 2 3; do
        output=$(iw "$1" scan 2>&1)
        if echo "$output" | grep -qi "busy"; then
            info "Interfaccia occupata, la libero e riprovo..."
            pulisci_connessioni
            resetta_interfaccia "$1"
        else
            break
        fi
    done
    while IFS= read -r riga; do
        [ -n "$riga" ] && RETI+=("$riga")
    done < <(echo "$output" | grep "SSID:" | sed 's/.*SSID: //' | sed '/^$/d' | sort -u)
}

# ---------- Connessioni ----------

test_connessione() {
    info "Verifico la connessione a internet..."
    sleep 3
    if ping -c 2 -W 4 1.1.1.1 >/dev/null 2>&1; then
        ok "Sei connesso a internet!"
        return 0
    else
        err "Rete connessa ma internet non risponde."
        echo "    Prova a lanciare:  sudo nc10-fix"
        return 1
    fi
}

connetti_wifi() {
    # $1 = SSID, $2 = password (vuota per rete aperta)
    local ssid="$1" pass="$2" wifi
    wifi=$(trova_interfaccia_wifi)
    if [ -z "$wifi" ]; then
        err "Nessuna interfaccia WiFi trovata."
        return 1
    fi

    pulisci_connessioni
    resetta_interfaccia "$wifi"

    local temp_conf="/tmp/wpa_temp.conf"
    # Creo il file con permessi ristretti (solo root può leggerlo)
    rm -f "$temp_conf"
    (umask 077; : > "$temp_conf")
    if [ -n "$pass" ]; then
        # grep -v elimina la riga #psk= che contiene la password in chiaro:
        # nel file resta solo l'hash derivato
        if ! wpa_passphrase "$ssid" "$pass" | grep -v '#psk=' >> "$temp_conf"; then
            err "Errore nella creazione del profilo (password sotto gli 8 caratteri?)."
            rm -f "$temp_conf"
            return 1
        fi
    else
        cat >> "$temp_conf" <<EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi

    info "Mi connetto a \"$ssid\"..."
    wpa_supplicant -B -i "$wifi" -D nl80211,wext -c "$temp_conf"
    sleep 4

    info "Richiedo un indirizzo IP..."
    dhclient -v "$wifi" 2>/dev/null

    local esito=1
    test_connessione && esito=0
    rm -f "$temp_conf"
    return $esito
}

connetti_usb() {
    echo ""
    echo "  1. Collega il telefono al computer con il cavo USB"
    echo "  2. Sul telefono attiva: Impostazioni > Hotspot e tethering > Tethering USB"
    echo ""
    read -rp "Quando hai fatto, premi INVIO..."

    info "Cerco l'interfaccia di tethering USB..."
    local usb="" tentativo=1
    while [ -z "$usb" ] && [ $tentativo -le 6 ]; do
        usb=$(trova_interfaccia_usb)
        [ -z "$usb" ] && sleep 2
        tentativo=$((tentativo + 1))
    done

    if [ -z "$usb" ]; then
        err "Nessuna interfaccia USB trovata."
        err "Verifica che il tethering USB sia attivo sul telefono e riprova."
        return 1
    fi

    info "Trovata interfaccia: $usb"
    pulisci_connessioni
    ip link set "$usb" up
    sleep 1

    info "Richiedo un indirizzo IP su $usb..."
    dhclient -v "$usb" 2>/dev/null
    test_connessione
}

connetti_ethernet() {
    local eth
    eth=$(trova_interfaccia_ethernet)
    if [ -z "$eth" ]; then
        err "Nessuna interfaccia ethernet (cavo) trovata."
        return 1
    fi
    info "Trovata interfaccia: $eth"
    pulisci_connessioni
    ip link set "$eth" up
    sleep 2
    info "Richiedo un indirizzo IP su $eth..."
    dhclient -v "$eth" 2>/dev/null
    test_connessione
}

# Sceglie una rete WiFi da un elenco numerato.
# Imposta la variabile globale SSID_SCELTO ("" se annullato).
scegli_ssid_numerato() {
    # $1 = interfaccia
    SSID_SCELTO=""
    info "Scansiono le reti disponibili..."
    scansiona_reti "$1"

    if [ ${#RETI[@]} -eq 0 ]; then
        err "Nessuna rete trovata. Prova ad avvicinarti al modem o lancia: sudo nc10-fix"
        return 1
    fi

    echo ""
    echo "Reti WiFi trovate:"
    local i=1
    for rete in "${RETI[@]}"; do
        printf "  %2d) %s\n" "$i" "$rete"
        i=$((i + 1))
    done
    echo ""
    read -rp "Scrivi il NUMERO della rete (o il nome esatto, o INVIO per annullare): " scelta

    if [ -z "$scelta" ]; then
        return 1
    elif [[ "$scelta" =~ ^[0-9]+$ ]] && [ "$scelta" -ge 1 ] && [ "$scelta" -le ${#RETI[@]} ]; then
        SSID_SCELTO="${RETI[$((scelta - 1))]}"
    else
        SSID_SCELTO="$scelta"
    fi
    ok "Rete scelta: $SSID_SCELTO"
    return 0
}
