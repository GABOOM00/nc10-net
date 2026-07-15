#!/usr/bin/env bash
#
# nc10-net — Selettore di connessione per Samsung NC10
# Menu all'avvio: casa (Vodafone), telefono via cavo USB, o nuova rete WiFi.
#
# Requisiti: NetworkManager (nmcli). Verifica con:  nmcli --version
#

# ============================================================
# CONFIGURAZIONE — modifica queste due righe con i tuoi dati
# ============================================================
HOME_SSID="Vodafone-XXXXXXX"      # <-- nome esatto della tua WiFi di casa
HOME_PASS=""                      # <-- password (lasciala vuota se la rete
                                  #     è già salvata in NetworkManager)
# ============================================================

VERDE='\033[0;32m'; ROSSO='\033[0;31m'; GIALLO='\033[1;33m'; RESET='\033[0m'

ok()   { echo -e "${VERDE}[OK]${RESET} $1"; }
err()  { echo -e "${ROSSO}[ERRORE]${RESET} $1"; }
info() { echo -e "${GIALLO}[...]${RESET} $1"; }

controlla_nmcli() {
    if ! command -v nmcli >/dev/null 2>&1; then
        err "nmcli non trovato. Installa NetworkManager:"
        echo "    sudo apt install network-manager"
        exit 1
    fi
}

test_connessione() {
    info "Verifico la connessione a internet..."
    sleep 3
    if ping -c 2 -W 4 1.1.1.1 >/dev/null 2>&1; then
        ok "Sei connesso a internet!"
        return 0
    else
        err "Connesso alla rete ma internet non risponde (o connessione fallita)."
        return 1
    fi
}

connetti_casa() {
    info "Accendo il WiFi..."
    nmcli radio wifi on
    sleep 2

    # Se la connessione è già salvata, la riattivo direttamente
    if nmcli -t -f NAME connection show | grep -Fxq "$HOME_SSID"; then
        info "Mi connetto alla rete di casa: $HOME_SSID"
        if nmcli connection up "$HOME_SSID"; then
            test_connessione; return
        fi
    fi

    # Altrimenti provo a connettermi da zero
    info "Cerco la rete $HOME_SSID..."
    nmcli device wifi rescan 2>/dev/null; sleep 4
    if [ -n "$HOME_PASS" ]; then
        nmcli device wifi connect "$HOME_SSID" password "$HOME_PASS"
    else
        nmcli device wifi connect "$HOME_SSID"
    fi

    if [ $? -eq 0 ]; then
        test_connessione
    else
        err "Connessione a $HOME_SSID fallita."
        err "Controlla che HOME_SSID e HOME_PASS in cima allo script siano giusti."
    fi
}

connetti_telefono() {
    echo ""
    echo "  1. Collega il telefono al computer con il cavo USB"
    echo "  2. Sul telefono attiva: Impostazioni > Hotspot e tethering > Tethering USB"
    echo ""
    read -rp "Quando hai fatto, premi INVIO..."

    info "Cerco l'interfaccia di tethering USB..."
    local iface=""
    for tentativo in 1 2 3 4 5 6; do
        # Le interfacce USB tethering di solito si chiamano usb0 o enp...u...
        iface=$(nmcli -t -f DEVICE,TYPE device | grep -E '^(usb|enp[0-9]+s[0-9]+u)' | cut -d: -f1 | head -n1)
        [ -n "$iface" ] && break
        sleep 2
    done

    if [ -z "$iface" ]; then
        err "Nessuna interfaccia USB trovata."
        err "Verifica che il tethering USB sia attivo sul telefono e riprova."
        return 1
    fi

    info "Trovata interfaccia: $iface — mi connetto..."
    if nmcli device connect "$iface"; then
        test_connessione
    else
        err "Connessione tramite $iface fallita."
    fi
}

connetti_nuova_rete() {
    info "Accendo il WiFi e cerco le reti disponibili..."
    nmcli radio wifi on
    nmcli device wifi rescan 2>/dev/null; sleep 4

    echo ""
    echo "Reti WiFi trovate:"
    nmcli -f SSID,SIGNAL,SECURITY device wifi list | head -n 15
    echo ""

    read -rp "Nome della rete (SSID): " ssid
    if [ -z "$ssid" ]; then
        err "SSID vuoto, annullo."
        return 1
    fi

    read -rsp "Password (lascia vuoto se la rete è aperta): " pass
    echo ""

    if [ -n "$pass" ]; then
        nmcli device wifi connect "$ssid" password "$pass"
    else
        nmcli device wifi connect "$ssid"
    fi

    if [ $? -eq 0 ]; then
        test_connessione
        ok "La rete è stata salvata: la prossima volta si connetterà da sola."
    else
        err "Connessione a \"$ssid\" fallita. Controlla SSID e password."
    fi
}

# ================= MENU PRINCIPALE =================
controlla_nmcli

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
